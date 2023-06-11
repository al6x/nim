import std/[httpcore, asynchttpserver, asyncnet, deques, os]
import base, ext/[url, async]
import ./support, ./helpers, ../core

let http_log = Log.init "http"

# Server -------------------------------------------------------------------------------------------
proc get_page[T](self: Session[T], app_el: El): SafeHtml =
  when compiles(self.app.page(app_el)): self.app.page(app_el)
  else:                                 default_html_page(app_el)

proc get_binary[T](self: Session[T], url: Url): BinaryResponse =
  when compiles(self.app.on_binary url): self.app.on_binary url
  else:                                  http_response "app.on_binary not defined", 400

proc handle_app_load[T](req: Request, sessions: Sessions[T], url: Url, build_session: BuildSession[T]): Future[void] {.async.} =
  # Creating session
  let session = build_session url
  sessions[][session.id] = session
  session.log.info "created"

  # Location event
  let location = InEvent(kind: location, location: url)
  session.inbox.add location
  session.log.with((location: url)).info "<<"

  # Processing in another async process, it's inefficient but help to avoid messy async error stack traces.
  while session.el.is_none: await sleep_async 1
  assert session.outbox.is_empty

  session.log.info ">> initial html"
  let page = get_page(session, session.el.get)
  await req.respond(page, "text/html; charset=UTF-8")

proc handle_app_in_event[T](req: Request, session: Session[T], events: seq[InEvent]): Future[void] {.async.} =
  # Processing happen in another async process, it's inefficient but help to avoid messy async error stack traces.
  session.inbox.add events
  if events.len == 1: session.log.with(events[0]).info "<<"
  else:               session.log.with((events: events)).info "<<"
  await req.respond("{}", "application/json")

proc handle_pull(req: Request, session: Session, pull_timeout_ms: int): Future[void] {.async.} =
  let timout_timer = timer_ms()
  while true:
    if not session.outbox.is_empty:
      let events = session.outbox
      session.outbox.clear
      if events.len == 1: session.log.with(events[0]).info ">>"
      else:               session.log.with((events: events)).info ">>"
      await req.respond_json events
      break
    if timout_timer() > pull_timeout_ms:
      await req.respond_json OutEvent(kind: ignore)
      break
    await sleep_async 1

proc handle_on_binary[T](req: Request, mono_id: string, url: Url, sessions: Sessions[T]): Future[void] {.async.} =
  if mono_id notin sessions[]:
    await req.respond(Http500, "Session expired")
  else:
    let session = sessions[][mono_id]
    let binary = get_binary(session, url)
    case binary.kind
    of BinaryResponseKind.file:
      await req.serve_file(binary.path)
    of BinaryResponseKind.http:
      await req.respond(HttpCode(binary.code), binary.content, new_http_headers(binary.headers))

proc build_http_handler[T](sessions: Sessions[T], build_session: BuildSession[T], asset_paths: seq[string], pull_timeout_ms: int): auto =
  return proc (req: Request): Future[void] {.gcsafe.} =

    let url = Url.init(req); let path_s = url.path_as_s
    if req.req_method == HttpGet: # GET
      if path_s =~ re"^/assets/" or path_s == "/favicon.ico":
        req.serve_asset_file(asset_paths, url)
      elif "mono_id" in url.params:
        req.handle_on_binary(url.params["mono_id"], url, sessions)
      else:
        req.handle_app_load(sessions, url, build_session)
    elif req.req_method == HttpPost: # POST
      let post_event = req.body.parse_json.json_to InEventEnvelope
      if post_event.mono_id notin sessions[]:
        req.respond_json OutEvent(kind: expired)
      else:
        let session = sessions[][post_event.mono_id]
        session.last_accessed_ms = timer_ms()
        case post_event.kind
        of events:
          req.handle_app_in_event(session, post_event.events)
        of pull:
          req.handle_pull(session, pull_timeout_ms)
        else:
          session.log.with((event: post_event)).error("unknown post event")
          req.respond_json OutEvent(kind: error, message: "unknown app in event")
    else:
      http_log.error(fmt"Unknown request ${req.req_method}: ${url}")
      # await req.respond "Unknown request"
      req.respond_json((error: "Unknown request"))

proc mono_assets_path(): seq[string] =
  # It had to be non-generic proc, otherwise it will be resolved as template from another file and
  # pahts will be wrong
  @[current_source_path().parent_dir.parent_dir.absolute_path & "/browser"]

proc run_http_server*[T](
  build_session:       BuildSession[T],
  port               = 2000,
  asset_paths        = seq[string].init,
  timer_event_ms     = 500,
  pull_timeout_ms    = 40000, # Default HTTP timeout seems to be 100sec, just to be safer making it smaller,
                              # to avoid potential problems if someone uses some HTTP proxy etc.
  sync_process: proc() = (proc = (discard)) # Add any additional periodic processing here
) =
  let session_timeout_ms = 2 * pull_timeout_ms # session timeout should be greather than poll timeout
  # Files with same names will be taken from first path when found, this way system assets like `page.html`
  # could be overriden.
  let sessions = Sessions[T]()
  var server = new_async_http_server()
  let asset_paths = asset_paths & mono_assets_path()
  let handler = build_http_handler(sessions, build_session, asset_paths, pull_timeout_ms)
  spawn_async server.serve(Port(port), handler, "localhost")

  add_timer((session_timeout_ms/2).int, () => sessions.collect_garbage(session_timeout_ms))

  # Triggering timer event periodically, to check for any background state changes
  add_timer(timer_event_ms, () => sessions.add_timer_event)

  http_log.with((port: port)).info "started"
  spawn_async(() => say "started", false)

  while true:
    poll 1
    sync_process()   # any additional periodic processing
    sessions.process # processing outside async, to have clean stack trace