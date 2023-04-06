import std/[httpcore, asynchttpserver, asyncnet, deques]
import base, ext/[url, async]
import ./session, ./helpers, ../app

let http_log = Log.init "http"

proc handle_app_load(req: Request, sessions: Sessions, apps: Apps, url: Url): Future[void] {.async.} =
  # Creating session, initial event and serving app.html
  let app = apps.get url
  let session_id = secure_random_token(6)
  let session = Session.init(session_id, app)
  sessions[][session_id] = session
  session.log.info "created"

  let event = InEvent(kind: location, path: url.path_parts, query: url.query)
  session.inbox.add_last event
  session.log.with(event).info "<<"

  await req.serve_app_html(url, session_id)

proc handle_app_in_event(req: Request, session: Session, event: InEvent): Future[void] {.async.} =
  session.inbox.add_last event
  session.log.with(event).info "<<"
  await req.respond_json seq[int].init

proc handle_pull(req: Request, session: Session, pull_timeout_ms: int): Future[void] {.async.} =
  let timer = timer_ms()
  while true:
    if not session.outbox.is_empty:
      let events = session.outbox.to_seq
      session.outbox.clear
      if events.len == 1:  session.log.with(events[0]).info ">>"
      else:                session.log.with(events).info ">>"
      await req.respond_json events
      break
    if timer() > pull_timeout_ms:
      await req.respond_json seq[int].init
      break
    await sleep_async(1)

proc build_http_handler(sessions: Sessions, apps: Apps, pull_timeout_ms: int): auto =
  return proc (req: Request): Future[void] {.async, gcsafe.} =
    let url = Url.init(req)
    if req.req_method == HttpGet: # GET
      if url.path =~ re"^/_assets/":
        await req.serve_asset_files(url)
      elif url.path == "/favicon.ico":
        await req.respond(Http404, "")
      else:
        await req.handle_app_load(sessions, apps, url)
    elif req.req_method == HttpPost: # POST
      let post_event = req.body.parse_json.json_to SessionPostEvent
      if post_event.session_id notin sessions[]:
        await req.respond_json @[SessionPullEvent(kind: expired)]
      else:
        let session = sessions[][post_event.session_id]
        session.last_accessed_ms = timer_ms()
        case post_event.kind
        of event:
          await req.handle_app_in_event(session, post_event.event)
        of pull:
          await req.handle_pull(session, pull_timeout_ms)
        else:
          session.log.with(event).error("unknown post event")
          await req.respond_json(@[SessionPullEvent(kind: error, message: "unknown app in event")])
    else:
      http_log.error(fmt"Unknown request ${req.req_method}: ${url}")
      await req.respond "Unknown request"

proc run_http_server*(
  apps:                Apps,
  port:                int,
  pull_timeout_ms    = 2000,
  session_timeout_ms = 4000
): void =
  let sessions = Sessions()
  var server = new_async_http_server()
  spawn_async server.serve(Port(port), build_http_handler(sessions, apps, pull_timeout_ms), "localhost")

  add_timer((session_timeout_ms/2).int, () => sessions.collect_garbage(session_timeout_ms), once = false)

  http_log.info "started"
  spawn_async(() => say "started", false)

  while true:
    poll 1
    sessions.process # extracting it from the async to have clean stack trace


# Test ---------------------------------------------------------------------------------------------
# type TestSession* = ref object

# proc process*(session: TestSession, event: JsonNode): Option[JsonNode] =
#   (%{ eval: "console.log(\"ok\")" }).some

type TestApp* = ref object of App

method process*(self: TestApp, event: InEvent): seq[OutEvent] =
  @[OutEvent(kind: eval, code: fmt"console.log('event {event.kind} processed')")]

if is_main_module:
  let apps = Apps()
  apps[]["test"] = proc: App = TestApp()
  run_http_server(apps, port = 2000)