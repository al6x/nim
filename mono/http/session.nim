import std/[deques]
import base, ../core

type SessionPostEventKind* = enum events, pull
type SessionPostEvent* = object
  mono_id*: string
  case kind*: SessionPostEventKind
  of events:
    events*: seq[InEvent]
  of pull:
    discard

type SessionPullEventKind* = enum events, ignore, expired, error
type SessionPullEvent* = object
  case kind*: SessionPullEventKind
  of events:
    events*: seq[OutEvent]
  of ignore:
    discard
  of expired:
    discard
  of error:
    message*: string

# Processing Browser events decoupled from the HTTP networking, to avoid async complications.
# Browser events are collected in indbox via async http handler, and then processed separatelly via
# sync process. Result of processing stored in outbox, which periodically checked by async HTTP handler
# and sent to Browser if needed.
type AppFn* = proc(events: seq[InEvent], mono_id: string): seq[OutEvent]

type Session* = ref object
  id*:               string
  app*:              AppFn
  inbox*:            seq[InEvent]
  outbox*:           seq[OutEvent]
  last_accessed_ms*: TimerMs

proc init*(_: type[Session], mono_id: string, app: AppFn): Session =
  Session(id: mono_id, app: app, last_accessed_ms: timer_ms())

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
  # p sessions
  for _, s in sessions: s.process

proc collect_garbage*(self: Sessions, session_timeout_ms: int) =
  let deleted = self[].delete (_, s) => s.last_accessed_ms() > session_timeout_ms
  for session in deleted.values: session.log.info("closed")

proc add_timer_event*(self: Sessions) =
  for id, session in self: session.inbox.add(InEvent(kind: timer))


# proc to(e: OutEvent, _: type[SessionPostEvent]): SessionPostEvent =
#   assert e.kind == eval
#   PullEvent(kind: eval, code: e.code)
