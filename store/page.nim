#!/usr/bin/env nim c -r

import base, base/[url, async]
import std/[deques, httpcore, asynchttpserver, asyncnet]
import page/helpers

let log = Log.init("Page")

type SessionData[S] = ref object
  id:               string
  session:          S
  inbox:            Deque[JsonNode]
  outbox:           Deque[JsonNode]
  last_accessed_ms: Timer

proc mprocess[S](sdata: SessionData[S]): void =
  while sdata.inbox.len > 0:
    let res = sdata.session.process sdata.inbox.pop_first
    if not res.is_empty: sdata.outbox.add_last(res.get)

proc mon_event[S](sdata: SessionData[S], event: JsonNode): JsonNode =
  log.with(sdata.id).info("session event")
  sdata.inbox.add_last(event)
  %{}

proc mon_pull[S](sdata: SessionData[S]): Option[JsonNode] =
  if sdata.outbox.len > 0: sdata.outbox.pop_first.some else: JsonNode.none

type Sessions[S] = Table[string, SessionData[S]]
type ProcessSession[S] = proc(session: S, event: JsonNode): Option[JsonNode]

proc run_page*[S](
  process_session:     ProcessSession[S],
  port:                int,
  pull_timeout_ms    = 2000,
  session_timeout_ms = 4000
): void =
  var sessions: Sessions[S]

  proc mprocess_sessions =
    let deleted = sessions.del (_, sdata) => sdata.last_accessed_ms() > session_timeout_ms
    for session_id in deleted: log.with(session_id).info("session closed")
    for _, sdata in sessions: sdata.mprocess

  proc http_handler(req: Request): Future[void] {.async, gcsafe.} =
    let url = Url.init(req.url)
    if req.req_method == HttpGet:
      if url.path =~ re"^/_client/":
        await req.serve_client_files(url)
      elif url.path == "/favicon.ico":
        await req.respond(Http404, "")
      else:
        let session_id = secure_random_token(6)
        log.with(session_id).info("session opened")
        await req.serve_client_page(url, session_id)
    elif req.req_method == HttpPost:
      let data = req.body.parse_json
      let (session_id, etype) = (data["session_id"].get_str, data["type"].get_str)
      let sdata = sessions.mget(session_id, () => SessionData[S](id: session_id))
      sdata.last_accessed_ms = timer_ms()

      if etype == "event":
        await req.respond_json(sdata.mon_event(data))
      elif etype == "pull":
        let timer = timer_ms()
        while true:
          if timer() > pull_timeout_ms:
            await req.respond_json(%{})
            break
          let res = sdata.mon_pull
          if not res.is_empty:
            await req.respond_json(res.get)
            break
          await sleep_async(1)
      else:
        log.with(session_id).warn("unknown request")
        await req.respond_json(%{})
    else:
      log.warn("unknown request")

  var server = new_async_http_server()
  spawn_async server.serve(Port(port), http_handler, "localhost")

  log.info "started"
  spawn_async((proc: Future[void] {.async.} = say "started"), false)

  while true:
    poll(1)
    # mprocess_sessions(process_session)
    mprocess_sessions()

# Test ---------------------------------------------------------------------------------------------
type TestSession* = ref object

proc process*(session: TestSession, event: JsonNode): Option[JsonNode] =
  (%{ eval: "console.log(\"ok\")" }).some

if is_main_module:
  run_page(process, port = 5000)