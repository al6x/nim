# How it works

Browser listens to UI events and sends it to server as `InEvent`.

Server session maintains UI tree, and listens for events, and when get event updates variables, executes listeners, calculates difference between new and old tree, and send set of diffs to Browser  `session.process(events: seq[InEvent]): seq[OutEvent]`

Browser got set of diffs to patch existing UI and updates it

In more details:

```Nim
session.process(events: seq[InEvent]): seq[OutEvent]

type
  InEvent* = object # see component.nim
    el*: seq[int]
    case kind*: InEventType
    of location: location*: Url
    of click:    click*: ClickEvent
    of keydown:  keydown*: KeydownEvent
    of change:   change*: ChangeEvent
    of timer:    discard # Triggered periodically, to check and pick any background changes in state

  OutEvent* = object # see session.nim
    case kind*: OutEventKind
    of update:  diffs*: seq[Diff]

Browser, JS: # see mono.ts
  document.on_any_ui_event     =>
    encode it as InEvent and send to Nim Server

  network.on_event_from_server =>
    decode OutEvent and get set of diffs
    apply diffs to current DOM and update it

Server, Nim:
  # IO layer
  on_browser_event => session.inbox.add(in_event)
  every_100ms      => check session.outbox queue, and send it to Browser.

  # UI processing
  every_100ms      => session.outbox.add(session.process(session.inbox)) # see session.nim

proc process(s: Session, in_events: seq[InEvent]): seq[OutEvent] = # see session.nim
  session has s.ui_tree (actually 2 trees, Components tree, and HTML elements tree)
  check if s.ui_tree has input/variable bindings that match in_events, and if so update variables
  check if s.ui_tree has action listener matching in_events, and if so execute it
  let new_ui_tree = s.root_component.render # see component.nim

  # Calculating efficient set of diffs, that should be applied to old tree to turn it into new tree
  let diffs = diff(s.ui_tree, new_ui_tree) # see diff.nim

  s.ui_tree = new_ui_tree
  @[OutEvent(kind: update, diffs: diffs)] # sending set of diffs to Browser
```

Take look at `session_test.nim` it tests this scenario.