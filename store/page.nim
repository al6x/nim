#!/usr/bin/env nim c -r

import base, base/[url, async]
import std/[deques, httpcore, asynchttpserver, asyncnet]
import page/helpers


# App ----------------------------------------------------------------------------------------------
type App* = ref object of RootObj
  id*: string

type Apps* = ref Table[string, proc: App]

# method run(app: App): void {.base.} = throw "not implemented"

proc get(apps: Apps, url: Url): (App, Deque[JsonNode]) =
  # Returns app and initial events, like going to given url
  let id = if url.host == "localhost": url.query.ensure("_app", "_app query parameter required") else: url.host
  let app = apps[].ensure(id, fmt"Error, unknown application '{id}'")()

  var query = url.query
  query.del "_app"
  let location_event = %{ type: "location", path: url.path.replace(re"/$", "").split("/"), query: query }

  (app, @[location_event].to_deque)


# Page ---------------------------------------------------------------------------------------------
let log = Log.init("Page")

# Processing Browser events decoupled from the HTTP networking, to avoid async complications.
# Browser events are collected in indbox via async http handler, and then processed separatelly via
# sync process. Result of processing stored in outbox, which periodically checked by async HTTP handler
# and sent to Browser if needed.
type Session = ref object
  id:               string
  app:              App
  inbox:            Deque[JsonNode]
  outbox:           Deque[JsonNode]
  last_accessed_ms: Timer

proc init(_: type[Session], session_id: string, app: App, inbox: Deque[JsonNode]): Session =
  Session(id: session_id, app: app, inbox: inbox)

proc mprocess*(s: Session, event: JsonNode): Option[JsonNode] =
  (%{ eval: "console.log(\"ok\")" }).some

proc mprocess(s: Session): void =
  while s.inbox.len > 0:
    let res = s.mprocess s.inbox.pop_first
    if not res.is_empty: s.outbox.add_last(res.get)

proc mon_event(s: Session, event: JsonNode): void =
  log.with(s.id).info("session event")
  s.inbox.add_last(event)

proc mon_pull(s: Session): Option[JsonNode] =
  if s.outbox.len > 0: s.outbox.pop_first.some else: JsonNode.none

type Sessions = ref Table[string, Session]
# type ProcessSession[S] = proc(session: S, event: JsonNode): Option[JsonNode]

proc mprocess(sessions: Sessions, session_timeout_ms: int) =
  let deleted = sessions[].del (_, s) => s.last_accessed_ms() > session_timeout_ms
  for session_id in deleted: log.with(session_id).info("session closed")
  for _, s in sessions: s.mprocess

proc mbuild_http_handler(sessions: Sessions, apps: Apps, pull_timeout_ms: int): auto =
  return proc (req: Request): Future[void] {.async, gcsafe.} =
    let url = Url.init(req)
    if req.req_method == HttpGet:
      if url.path =~ re"^/_client/":
        await req.serve_client_files(url)
      elif url.path == "/favicon.ico":
        await req.respond(Http404, "")
      else:
        let session_id = secure_random_token(6)
        await req.serve_client_page(url, session_id)
    elif req.req_method == HttpPost:
      let data = req.body.parse_json
      let (session_id, etype) = (data["session_id"].get_str, data["type"].get_str)
      if session_id notin sessions[]:
        let (app, inbox) = apps.get(url)
        let session = Session.init(session_id, app, inbox)
        sessions[][session_id] = session
        log.with(session_id).info("session opened")
      let session = sessions[][session_id]
      session.last_accessed_ms = timer_ms()

      if etype == "event":
        let event = data["event"].ensure((e) => e.kind == JObject, "invalid event type")
        session.mon_event(event)
        await req.respond_json(%{})
      elif etype == "pull":
        let timer = timer_ms()
        while true:
          if timer() > pull_timeout_ms:
            await req.respond_json(%{})
            break
          let res = session.mon_pull
          if not res.is_empty:
            await req.respond_json(res.get)
            break
          await sleep_async(1)
      else:
        log.with(session_id).warn("unknown request")
        await req.respond_json(%{})
    else:
      log.warn("unknown request")

proc run_page*(
  apps:                Apps,
  port:                int,
  pull_timeout_ms    = 2000,
  session_timeout_ms = 4000
): void =
  let sessions = Sessions()
  var server = new_async_http_server()
  spawn_async server.serve(Port(port), mbuild_http_handler(sessions, apps, pull_timeout_ms), "localhost")

  log.info "started"
  spawn_async(() => say "started", false)

  while true:
    poll(1)
    sessions.mprocess(session_timeout_ms)


# Debug --------------------------------------------------------------------------------------------


type Runtime = ref object of App

method run(app: Runtime): void =
  throw "not implemented"






# Test ---------------------------------------------------------------------------------------------
# type TestSession* = ref object

# proc process*(session: TestSession, event: JsonNode): Option[JsonNode] =
#   (%{ eval: "console.log(\"ok\")" }).some

if is_main_module:
  let apps = Apps()
  apps[]["runtime"] = proc: App = Runtime()
  run_page(apps, port = 8080)