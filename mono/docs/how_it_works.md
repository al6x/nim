# How it works

Browser listens to UI events and sends it to server as `InEvent`.

Server session maintains UI tree, and listens for events. And when get event - updates variables, executes listeners, calculates difference between new and old tree, and send set of diffs to Browser. All happens in `session.process(events: seq[InEvent]): seq[OutEvent]`.

Browser got set of diffs to patch existing UI and updates it

# In details

Browser has tiny JS client, it forwards UI events to Nim Server, and executes commands send back from Nim Server.

```Nim
Browser, JS: # see mono.ts
  document.on_any_ui_event     =>
    encode it as InEvent and send to Nim Server

  network.on_event_from_server =>
    decode OutEvent and get set of diffs
    apply diffs to current DOM to update it
```

Server maintains the actual UI, listens for events from Browser, executes UI actions, calculates set of diffs that
should be sent to Browser to update old UI into new.

```Nim
type
  InEvent* = object # see component.nim
    case kind*: InEventType
    of location: location*: Url
    of click:    click*: ClickEvent
    of keydown:  keydown*: KeydownEvent
    of change:   change*: ChangeEvent
    of timer:    discard # Triggered periodically, to check and pick any background changes in state

  OutEvent* = object # see session.nim
    case kind*: OutEventKind
    of update:  diffs*: seq[Diff]

Server, Nim:
  # IO layer
  on_browser_event => session.inbox.add(in_event)
  every_100ms      => check session.outbox queue, and send it to Browser.

  # UI processing, see session.nim
  every_100ms      => unless inbox.is_empty: session.outbox.add(session.process(session.inbox))

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