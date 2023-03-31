import std/[deques, httpcore, asynchttpserver, asyncnet]
import base, base/[url, async], web/[helpers, app]

let log = Log.init("Page")

type PullEventKind = enum expired, eval, ignore
type PullEvent = object
  case kind: PullEventKind
  of expired:
    discard
  of eval:
    code: string
  of ignore:
    discard

proc to(e: OutEvent, _: type[PullEvent]): PullEvent =
  assert e.kind == eval
  PullEvent(kind: eval, code: e.code)

# Processing Browser events decoupled from the HTTP networking, to avoid async complications.
# Browser events are collected in indbox via async http handler, and then processed separatelly via
# sync process. Result of processing stored in outbox, which periodically checked by async HTTP handler
# and sent to Browser if needed.
type Session = ref object
  id:               string
  app:              App
  inbox:            Deque[InEvent]
  outbox:           Deque[OutEvent]
  last_accessed_ms: Timer

proc init(_: type[Session], session_id: string, app: App, inbox: Deque[InEvent]): Session =
  Session(id: session_id, app: app, inbox: inbox, last_accessed_ms: timer_ms())

proc process(s: Session): void =
  while s.inbox.len > 0:
    let res = s.app.process s.inbox.pop_first
    if not res.is_empty: s.outbox.add_last(res.get)

proc on_event(s: Session, event: InEvent): void =
  log.with(s.id).with(event.to_json).info("session event")
  s.inbox.add_last(event)

proc on_pull(s: Session): Option[PullEvent] =
  if s.outbox.len > 0: s.outbox.pop_first.to(PullEvent).some else: PullEvent.none

type Sessions = ref Table[string, Session]
# type ProcessSession[S] = proc(session: S, event: JsonNode): Option[JsonNode]

proc process(sessions: Sessions) =
  for _, s in sessions: s.process

proc collect_garbage(sessions: Sessions, session_timeout_ms: int) =
  let deleted = sessions[].del (_, s) => s.last_accessed_ms() > session_timeout_ms
  for session_id in deleted: log.with(session_id).info("session closed")

proc build_http_handler(sessions: Sessions, apps: Apps, pull_timeout_ms: int): auto =
  return proc (req: Request): Future[void] {.async, gcsafe.} =
    let url = Url.init(req)
    if req.req_method == HttpGet:
      if url.path =~ re"^/_client/":
        await req.serve_client_files(url)
      elif url.path == "/favicon.ico":
        await req.respond(Http404, "")
      else:
        let session_id = secure_random_token(6)
        let (app, initial_event) = apps.get(url)
        let session = Session.init(session_id, app, @[initial_event].to_deque)
        sessions[][session_id] = session
        log.with(session_id).with(initial_event.to_json).info("session opened")
        await req.serve_client_page(url, session_id)
    elif req.req_method == HttpPost:
      let data = req.body.parse_json
      let (session_id, kind) = (data["session_id"].get_str, data["kind"].get_str)
      if session_id notin sessions[]:
        await req.respond_json(PullEvent(kind: expired))
      else:
        let session = sessions[][session_id]
        session.last_accessed_ms = timer_ms()
        if kind == "event":
          let event = data["event"].ensure((e) => e.kind == JObject, "invalid event type").json_to(InEvent)
          session.on_event(event)
          await req.respond_json(PullEvent(kind: ignore))
        elif kind == "pull":
          let timer = timer_ms()
          while true:
            if timer() > pull_timeout_ms:
              await req.respond_json(PullEvent(kind: ignore))
              break
            let res = session.on_pull
            if not res.is_empty:
              await req.respond_json(res.get)
              break
            await sleep_async(1)
        else:
          log.with(session_id).warning("unknown request")
          await req.respond_json(PullEvent(kind: ignore))
    else:
      log.warning("unknown request")

proc run_page*(
  apps:                Apps,
  port:                int,
  pull_timeout_ms    = 2000,
  session_timeout_ms = 4000
): void =
  let sessions = Sessions()
  var server = new_async_http_server()
  spawn_async server.serve(Port(port), build_http_handler(sessions, apps, pull_timeout_ms), "localhost")

  # add_timer((session_timeout_ms/2).int, () => sessions.collect_garbage(session_timeout_ms), once = false)
  add_timer(100, () => sessions.collect_garbage(session_timeout_ms), once = false)

  log.info "started"
  spawn_async(() => say "started", false)

  while true:
    poll(1)
    sessions.process() # extracting it from the async to have clean stack trace


# Test ---------------------------------------------------------------------------------------------
# type TestSession* = ref object

# proc process*(session: TestSession, event: JsonNode): Option[JsonNode] =
#   (%{ eval: "console.log(\"ok\")" }).some

# if is_main_module:
#   let apps = Apps()
#   apps[]["runtime"] = proc: App = Runtime()
#   run_page(apps, port = 8080)