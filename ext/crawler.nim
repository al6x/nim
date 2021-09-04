require std/os
require base, base/doc, ext/persistence

todo "when waiting - reduce expiration x2 and pass to should_process"
todo "keep track of duration for 1 month, cap by time, the current duration penalizing is wrong"

# Defaults -----------------------------------------------------------------------------------------
let default_retry_timeout     = 5.minutes
let default_max_retry_timeout = 4.hours


# Job ----------------------------------------------------------------------------------------------
type ShouldProcess* = tuple[process: bool, reason: string]

type LastProcessed* = tuple[timestamp: Time, version: int]

type Job* = ref object of RootObj
  id*:       string
  last*:     Fallible[LastProcessed]
  priority*: int

type Jobs* = ref Table[string, Job]

method should_process*(job: Job, jobs: Jobs): ShouldProcess {.base.} = throw "not implemented"
method process*(job: Job): LastProcessed {.base.} = throw "not implemented"
method after*(job: Job): void {.base.} = discard


# JobState -----------------------------------------------------------------------------------------
type HistoryItem = object
  duration:        int
  crawler_version: int
  timestamp:       Time
  case is_error: bool
  of false:
    discard
  of true:
    error: string

type JobState = object
  history:        seq[HistoryItem] # reversed, [last, previous, ...]
  retry_at:       Option[Time]
  total_duration: int

proc recent_errors_count(state: JobState): int =
  for item in state.history:
    if item.is_error: result.inc else: return


# Crawler ------------------------------------------------------------------------------------------
type JobStates = Table[string, JobState]
type JobErrors = Table[string, string]

type Crawler* = ref object
  id:                string
  version:           int
  jobs:              Jobs
  job_states:        JobStates
  data_dir:          string
  focus:             HashSet[string]
  retry_timeout:     TInterval
  max_retry_timeout: TInterval


# Log ----------------------------------------------------------------------------------------------
proc log(crawler_id: string): Log  = Log.init(crawler_id)
proc log(crawler: Crawler): Log = log(crawler.id)


# init ---------------------------------------------------------------------------------------------
proc init*(
  _:                  type[Crawler],
  id:                 string,
  version:            int,
  jobs:               seq[Job],
  data_dir:           string,
  focus:              seq[string],
  retry_timeout     = default_retry_timeout,
  max_retry_timeout = default_max_retry_timeout
): Crawler =
  # Loading job states
  let ids = jobs.pick(id).to_hash_set()
  assert ids.len == jobs.len, "there are jobs with same ids"
  var job_states = JobStates
    .read_from(fmt"{data_dir}/{id}-crawler.json", () => JobStates())
    .filter((_, id) => id in ids) # Removing states for old jobs

  # Cleaning retry when restarted
  for id, _ in job_states: job_states[id].retry_at = Time.none

  # Adding states for new jobs
  for job in jobs:
    if not (job.id in job_states): job_states[job.id] = JobState()

  Crawler(
    id:                id,
    version:           version,
    jobs:              jobs.to_table((j) => j.id).to_ref,
    data_dir:          data_dir,
    retry_timeout:     retry_timeout,
    focus:             focus.to_set,
    max_retry_timeout: max_retry_timeout,
    job_states:        job_states,
  )


# get_errors -----------------------------------------------------------------------------
proc get_errors(states: JobStates): JobErrors =
  for id, state in states:
    if state.recent_errors_count > 1:
      result[id] = state.history[0].error


# save -----------------------------------------------------------------------------------
proc save(crawler: Crawler): void =
  crawler.job_states.write_to fmt"{crawler.data_dir}/{crawler.id}-crawler.json"
  crawler.job_states.get_errors.write_to fmt"{crawler.data_dir}/{crawler.id}-crawler-errors.json"
  crawler.log.debug "state saved"


# process_job --------------------------------------------------------------------------------------
proc process_job(crawler: var Crawler, id: string, reason: string): void =
  let log   = crawler.log
  var job   = crawler.jobs[id]
  var state = crawler.job_states[id]

  # Processing
  let tic = timer_sec()
  let history_size = 5
  try:
    log.with((id: job.id, reason: reason)).info "processing '{id}', {reason}"

    job.last = job.process().success

    # Processing after
    # log.with((id: job.id)).info "{id} after processing"
    job.after()

    let duration = tic()
    log.with((id: job.id, duration: duration)).info "processed  '{id}' in {duration} sec"

    # Updating state
    state.history.prepend_capped(HistoryItem(
      duration:        duration,
      crawler_version: crawler.version,
      timestamp:       Time.now,
      is_error:        false
    ), history_size)
    state.retry_at = Time.none
  except:
    let (duration, error) = (tic(), get_current_exception().message)
    state.history.prepend_capped(HistoryItem(
      duration:        duration,
      crawler_version: crawler.version,
      timestamp:       Time.now,
      is_error:        true,
      error:           error
    ), history_size)

    let retry_count = state.recent_errors_count
    let retry_at: Time = Time.now + min(
      crawler.retry_timeout.seconds * 2.pow(retry_count - 1),
      crawler.max_retry_timeout.seconds
    ).seconds

    state.retry_at = retry_at.some
    crawler.job_states[id] = state

    let log_data = log.with((id: job.id, duration: duration, retry_count: retry_count, error: error))
    if retry_count > 1:
      log_data.warn "can't process '{id}' after {duration} sec, {retry_count} time, '{error}'"
    else:
      log_data.info "can't process '{id}' after {duration} sec, {retry_count} time, will be retried, '{error}'"

  crawler.jobs[id] = job

  state.total_duration = state.history.pick(duration).sum
  crawler.job_states[id] = state

# run ------------------------------------------------------------------------------------
proc run*(crawler: var Crawler): void =
  let log = crawler.log
  log.with((version: crawler.version)).info "started v{version}"
  while true:
    # Building queue to process
    let now = Time.now
    var queue: seq[tuple[job: Job, state: JobState, reason: string]] = @[]

    if not crawler.focus.is_empty:
      for job in crawler.jobs.values:
        if job.id in crawler.focus:
          queue.add((job, crawler.job_states[job.id], "focus"))
    else:
      for job in crawler.jobs.values:
        let state = crawler.job_states[job.id]
        if state.retry_at.is_blank or state.retry_at.get < now:
          # Checking `should_process` even if `retry_at < now`, because it could be already processed,
          # but state hasn't been saved because crawler crashed.
          let (should_process, reason) = job.should_process(crawler.jobs)
          if should_process: queue.add((job, state, reason))

    # p queue.map((j) => j.job.id).join("\n")
    log
      .with((counts: queue.count_by((job) => $(job.job.type))))
      .info("queue {counts} jobs")

    # Sorting and batching
    let sorted = queue.sort_by((job) => (-job.job.priority, job.state.total_duration))
    let batch = sorted.take(5)

    # Processing
    for job in batch:
      crawler.process_job(job.job.id, job.reason)

    # Saving or sleeping if there's nothing to process
    # Would be better to save state every minute, instead of for every batch.
    if not batch.is_empty:
      crawler.save()
    else:
      log.info "all processed, waiting"
      sleep(5.minutes.seconds * 1000)

doc("Crawler", """
Features:

- Different Job types
- Job priority
- Distributing jobs fairly, penalizing long taking jobs
- Retrying failed jobs with progressive delays
- Preserving state after restart
- Explanation for every job why it should be run
- Reporting errors

""", ["Data Sources"])