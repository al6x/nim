# How it works

Browser listens to UI events and forwards it to server as `InEvent`.

Server session maintains UI tree, and listens for events. And when get event - updates variables, executes listeners, calculates difference between new and old tree, and send set of diffs to Browser. All happens in `session.process(events: seq[InEvent]): seq[OutEvent]`.

Browser got set of diffs and patches existing UI to update it.

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
  # Server session mimics Actor, it has inbox and outbox queue and works by executing `process` function.

  # IO layer
  on_browser_event   => session.inbox.add(in_event)
  check_periodically => unless session.outbox.is_empty: send it to Browser.

  # UI processing, see session.nim
  check_periodically => unless session.inbox.is_empty: session.outbox.add(session.process(session.inbox))

proc process(s: Session, in_events: seq[InEvent]): seq[OutEvent] = # see session.nim
  # Session has current UI tree, s.ui_tree. Actually 2 trees, Components tree, and HTML elements tree,
  # but for simplicity we pretent that there's just one tree.

  # Updating State a) updating inputs (in-binding, inputs -> variables), and b) executing event listeners
  check if s.ui_tree has input/variable bindings that match in_events, and if so update variables
  check if s.ui_tree has action listener matching in_events, and if so execute it

  # a) Rendering new UI based on the new State, and b) updating inputs (out-binding, variables -> inputs)
  let new_ui_tree = s.root_component.render # see component.nim

  # Calculating efficient set of diffs, that should be applied to old tree to turn it into new tree
  let diffs = diff(s.ui_tree, new_ui_tree) # see diff.nim
  s.ui_tree = new_ui_tree

  # Storing diffs in out queue, that will be sent back to Browser
  @[OutEvent(kind: update, diffs: diffs)]
```

And there are couple of optimisations to make it more efficient, like throttling (batching actually) events and skipping rendering in cases when we know there were no changes to UI state or DB state. Handlign DB state depends on concrete use case and may require some sort of versioning, to check quickly if DB data has changed.

Take look at `session_test.nim` it tests this scenario.