import std/[httpcore, asynchttpserver, asyncnet, deques, os]
import base, ext/[url, async]
import ./session, ./helpers, ../core

let http_log = Log.init "http"

# Apps ---------------------------------------------------------------------------------------------
type AppPage*  = proc(initial_root_el: JsonNode): string
type BuildApp* = proc (url: Url): tuple[page: AppPage, app: App]

proc handle_app_load(
  req: Request, sessions: Sessions, url: Url, build_app: BuildApp, asset_paths: seq[string],
): Future[void] {.async.} =
  # Creating session, initial location event and serving app.html
  let (page, app) = build_app url
  let mono_id = secure_random_token(6)
  let session = Session.init(mono_id, app)
  sessions[][mono_id] = session
  session.log.info "created"
  let location = InEvent(kind: location, location: url)
  session.inbox.add location
  session.log.with((location: url)).info "<<"

  # Processing in another async process, it's inefficient but help to avoid messy async error stack traces.
  while session.outbox.is_empty: await sleep_async 1

  let root_el = session.outbox.initial_root_el
  session.outbox.clear
  session.log.info ">> initial html"

  await req.respond(page(root_el), "text/html; charset=UTF-8")

proc handle_app_in_event(req: Request, session: Session, events: seq[InEvent]): Future[void] {.async.} =
  # Processing happen in another async process, it's inefficient but help to avoid messy async error stack traces.
  session.inbox.add events
  for event in events:
    session.log.with(event).info "<<"
  await req.respond("{}", "application/json")

proc handle_pull(req: Request, session: Session, pull_timeout_ms: int): Future[void] {.async.} =
  let timout_timer = timer_ms()
  while true:
    if not session.outbox.is_empty:
      let events = session.outbox
      session.outbox.clear
      for event in events:
        session.log.with(event).info ">>"
      await req.respond_json SessionPullEvent(kind: SessionPullEventKind.events, events: events)
      break
    if timout_timer() > pull_timeout_ms:
      await req.respond_json SessionPullEvent(kind: ignore)
      break
    await sleep_async 1

proc build_http_handler(
  sessions: Sessions, build_app: BuildApp, asset_paths: seq[string], pull_timeout_ms: int
): auto =
  return proc (req: Request): Future[void] {.async, gcsafe.} =
    let url = Url.init(req); let path_s = url.path_as_s
    if req.req_method == HttpGet: # GET
      if path_s =~ re"^/assets/":
        await req.serve_asset_file(asset_paths, url)
      elif path_s == "/favicon.ico":
        # await req.respond(Http404, "")
        await req.serve_asset_file(asset_paths, url)
      else:
        await req.handle_app_load(sessions, url, build_app, asset_paths)
    elif req.req_method == HttpPost: # POST
      let post_event = req.body.parse_json.json_to SessionPostEvent
      if post_event.mono_id notin sessions[]:
        await req.respond_json SessionPullEvent(kind: expired)
      else:
        let session = sessions[][post_event.mono_id]
        session.last_accessed_ms = timer_ms()
        case post_event.kind
        of events:
          await req.handle_app_in_event(session, post_event.events)
        of pull:
          await req.handle_pull(session, pull_timeout_ms)
        else:
          session.log.with((event: post_event)).error("unknown post event")
          await req.respond_json SessionPullEvent(kind: error, message: "unknown app in event")
    else:
      http_log.error(fmt"Unknown request ${req.req_method}: ${url}")
      # await req.respond "Unknown request"
      await req.respond_json((error: "Unknown request"))

proc run_http_server*(
  build_app:           BuildApp,
  port:                int,
  asset_paths        = seq[string].init,
  timer_event_ms     = 500,
  pull_timeout_ms    = 2000,
  session_timeout_ms = 6000
) =
  # Files with same names will be taken from first path when found, this way system assets like `page.html`
  # could be overriden.
  var asset_paths = asset_paths & [current_source_path().parent_dir.parent_dir.absolute_path & "/browser"]

  let sessions = Sessions()
  var server = new_async_http_server()
  let handler = build_http_handler(sessions, build_app, asset_paths, pull_timeout_ms)
  spawn_async server.serve(Port(port), handler, "localhost")

  add_timer((session_timeout_ms/2).int, () => sessions.collect_garbage(session_timeout_ms), once = false)

  # Triggering timer event periodically, to check for any background state changes
  add_timer(timer_event_ms, () => sessions.add_timer_event, once = false)

  http_log.with((port: port)).info "started"
  spawn_async(() => say "started", false)

  while true:
    poll 1
    sessions.process # processing outside async, to have clean stack trace


# Test ---------------------------------------------------------------------------------------------
# when is_main_module:
#   import ../examples/todo
#   run_todo()

# let id = if url.host == "localhost": url.query.ensure("_app", "_app query parameter required") else: url.host
# self[].ensure(id, fmt"Error, unknown application '{id}'")()old_attrs