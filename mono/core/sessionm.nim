import std/deques
import base, ext/url, ./component, ./mono_el, ./diff

type
  InEventEnvelopeKind* = enum events, pull
  InEventEnvelope* = object
    mono_id*: string
    case kind*: InEventEnvelopeKind
    of events: events*: seq[InEvent]
    of pull:   discard

  OutEventKind* = enum eval, update, ignore, expired, error
  OutEvent* = object
    case kind*: OutEventKind
    of eval:    code*: string
    of update:  diffs*: seq[Diff]
    of ignore:  discard
    of expired: discard
    of error:   message*: string

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
  Session* = ref object of RootObj
    id*:     string
    inbox*:  seq[InEvent]
    outbox*: seq[OutEvent]
    app*:    Component
    el*:     Option[El] # UI tree from the last app render
    last_accessed_ms*: TimerMs

method forward_process*(self: Session, events: openarray[InEvent]): Option[El] {.base.} = throw "Not implemented"
method forward_page*(self: Session, el: El): SafeHtml {.base.} = throw "Not implemented"
method forward_on_binary*(self: Session, url: Url): BinaryResponse {.base.} = throw "Not implemented"

proc log*(self: Session): Log =
  Log.init("Session", self.id)

method process*(self: Session): bool {.base.} =
  if self.inbox.is_empty: return

  let inbox = self.inbox.copy
  self.inbox.clear

  let oel = self.forward_process(inbox)
  if oel.is_none: return
  let el = oel.get

  el.attrs["mono_id"] = self.id
  if self.el.is_some:
    let diffs = diff(@[], self.el.get, el)
    unless diffs.is_empty: self.outbox.add OutEvent(kind: update, diffs: diffs)
  self.el = el.some
  true

type Sessions* = ref Table[string, Session]

proc process*(sessions: Sessions) =
  for _, s in sessions: discard s.process

proc collect_garbage*(self: Sessions, session_timeout_ms: int) =
  let deleted = self[].delete (_, s) => s.last_accessed_ms() > session_timeout_ms
  for session in deleted.values: session.log.info("closed")

proc add_timer_event*(self: Sessions) =
  for id, session in self: session.inbox.add(InEvent(kind: timer))

proc file_response*(path: string): BinaryResponse =
  BinaryResponse(kind: file, path: path)

proc http_response*(content: string, code = 200, headers = seq[(string, string)].init): BinaryResponse =
  BinaryResponse(kind: http, content: content, code: code, headers: headers)

# Helpers ------------------------------------------------------------------------------------------
template define_session*(SessionType, ComponentType) =
  # Magical code to overcome Nim inability to store generics in collection and autocast to subclass.
  # Defining methods on Session, forwarding calls to Component subclass.
  type SessionType* = ref object of Session

  proc init*(_: type[SessionType], app: ComponentType): SessionType =
    SessionType(id: secure_random_token(6), last_accessed_ms: timer_ms(), app: app)

  method forward_process*(self: SessionType, events: openarray[InEvent]): Option[El] =
    let app: ComponentType = self.app.ComponentType
    app.process(self.el, events)

  method forward_page*(self: SessionType, app_el: El): SafeHtml =
    let app: ComponentType = self.app.ComponentType
    when compiles(app.page(app_el)): app.page(app_el)
    else:                            default_html_page(app_el)

  method forward_on_binary*(self: SessionType, url: Url): BinaryResponse =
    let app: ComponentType = self.app.ComponentType
    when compiles(app.on_binary url): app.on_binary url
    else:                             http_response "app.on_binary not defined", 400

when is_main_module:
  # Testing
  proc default_html_page*(el: El): SafeHtml = discard

  type App = ref object of Component
  proc render*(self: App): El = discard
  # proc page*(self: App, session: Session, el: El): SafeHtml = discard

  define_session(AppSession, App)
  p AppSession()