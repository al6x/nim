import std/[deques]
import base, ext/url, ./component

type
  SessionPostEventKind* = enum events, pull
  SessionPostEvent* = object
    mono_id*: string
    case kind*: SessionPostEventKind
    of events:
      events*: seq[InEvent]
    of pull:
      discard

  SessionPullEventKind* = enum events, ignore, expired, error
  SessionPullEvent* = object
    case kind*: SessionPullEventKind
    of events:
      events*: seq[OutEvent]
    of ignore:
      discard
    of expired:
      discard
    of error:
      message*: string

  BinaryResponseKind* = enum file, http
  BinaryResponse* = object
    case kind*: BinaryResponseKind
    of file:
      path*: string
    of http:
      content*: string
      code*:    int
      headers*: seq[(string, string)]

  # Processing Browser events decoupled from the HTTP networking, to avoid async complications.
  # Browser events are collected in indbox via async http handler, and then processed separatelly via
  # sync process. Result of processing stored in outbox, which periodically checked by async HTTP handler
  # and sent to Browser if needed.
  AppFn*    = proc(events: seq[InEvent], mono_id: string): seq[OutEvent]
  PageFn*   = proc(initial_root_el: JsonNode): string
  OnBinary* = proc(url: Url): BinaryResponse

  Session* = ref object
    id*:               string
    page*:             PageFn
    app*:              AppFn
    on_binary*:        Option[OnBinary]
    inbox*:            seq[InEvent]
    outbox*:           seq[OutEvent]
    last_accessed_ms*: TimerMs

var session* {.threadvar.}: Session
template with_session*(s: Session, code) =
  session = s
  defer: session = nil
  code

proc init*(_: type[Session], mono_id: string): Session =
  Session(id: mono_id, last_accessed_ms: timer_ms())

proc log*(self: Session): Log =
  Log.init("Session", self.id)

proc process(self: Session) =
  if self.inbox.is_empty: return
  let inbox = self.inbox.copy
  self.inbox.clear
  self.outbox.add self.app(inbox, self.id)

type Sessions* = ref Table[string, Session]
# type ProcessSession[S] = proc(session: S, event: JsonNode): Option[JsonNode]

proc process*(sessions: Sessions) =
  for _, s in sessions:
    with_session s:
      s.process

proc collect_garbage*(self: Sessions, session_timeout_ms: int) =
  let deleted = self[].delete (_, s) => s.last_accessed_ms() > session_timeout_ms
  for session in deleted.values: session.log.info("closed")

proc add_timer_event*(self: Sessions) =
  for id, session in self: session.inbox.add(InEvent(kind: timer))

proc file_response*(path: string): BinaryResponse =
  BinaryResponse(kind: file, path: path)

proc http_response*(content: string, code = 200, headers = seq[(string, string)].init): BinaryResponse =
  BinaryResponse(kind: http, content: content, code: code, headers: headers)