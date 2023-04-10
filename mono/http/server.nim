import std/[httpcore, asynchttpserver, asyncnet, deques]
import base, ext/[url, async]
import ./session, ./helpers, ../component, ../h

let http_log = Log.init "http"

# Apps ---------------------------------------------------------------------------------------------
type BuildApp* = (Url) -> App

proc handle_app_load(req: Request, sessions: Sessions, url: Url, build_app: BuildApp): Future[void] {.async.} =
  # Creating session, initial event and serving app.html
  let app = build_app url
  let session_id = secure_random_token(6)
  let session = Session.init(session_id, app)
  sessions[][session_id] = session
  session.log.info "created"

  # Processing in another async process, it's inefficient but help to avoid messy async error stack traces.
  let event = InEvent(kind: location, location: url)
  session.inbox.add event
  session.log.with(event).info "<<"
  while session.outbox.is_empty: await sleep_async(1)
  let html = session.outbox.to_html
  session.outbox.clear
  session.log.info ">> initial html"

  await req.serve_app_html(url, session_id, html)

proc handle_app_in_event(req: Request, session: Session, event: InEvent): Future[void] {.async.} =
  # Processing happen in another async process, it's inefficient but help to avoid messy async error stack traces.
  session.inbox.add event
  session.log.with(event).info "<<"
  await req.respond_json seq[int].init

proc handle_pull(req: Request, session: Session, pull_timeout_ms: int): Future[void] {.async.} =
  let timer = timer_ms()
  while true:
    if not session.outbox.is_empty:
      let events = session.outbox
      session.outbox.clear
      if events.len == 1:  session.log.with(events[0]).info ">>"
      else:                session.log.with(events).info ">>"
      await req.respond_json events
      break
    if timer() > pull_timeout_ms:
      await req.respond_json seq[int].init
      break
    await sleep_async(1)

proc build_http_handler(sessions: Sessions, build_app: BuildApp, pull_timeout_ms: int): auto =
  return proc (req: Request): Future[void] {.async, gcsafe.} =
    let url = Url.init(req)
    if req.req_method == HttpGet: # GET
      if url.path =~ re"^/_assets/":
        await req.serve_asset_files(url)
      elif url.path == "/favicon.ico":
        await req.respond(Http404, "")
      else:
        await req.handle_app_load(sessions, url, build_app)
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
  build_app:           BuildApp,
  port:                int,
  pull_timeout_ms    = 2000,
  session_timeout_ms = 6000
): void =
  let sessions = Sessions()
  var server = new_async_http_server()
  spawn_async server.serve(Port(port), build_http_handler(sessions, build_app, pull_timeout_ms), "localhost")

  add_timer((session_timeout_ms/2).int, () => sessions.collect_garbage(session_timeout_ms), once = false)

  http_log.info "started"
  spawn_async(() => say "started", false)

  while true:
    poll 1
    sessions.process # extracting it from the async to have clean stack trace


# Test ---------------------------------------------------------------------------------------------
when is_main_module:
  import ../examples/todo

  proc build_app(url: Url): App =
    let app = TodosView()
    app.set_attrs()
    return proc(events: seq[InEvent]): seq[OutEvent] =
      app.process events

  run_http_server(build_app, port = 2000)

# let id = if url.host == "localhost": url.query.ensure("_app", "_app query parameter required") else: url.host
# self[].ensure(id, fmt"Error, unknown application '{id}'")()old_attrs