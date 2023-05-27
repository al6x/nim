import base, std/macros, ext/url
import ./mono_el, ./diff

type
  InEventType* = enum location, click, dblclick, keydown, change, blur, input, timer

  InEvent* = object
    el*: seq[int]
    case kind*: InEventType
    of location:
      location*: Url
    of click:
      click*: ClickEvent
    of dblclick:
      dblclick*: ClickEvent
    of keydown:
      keydown*: KeydownEvent
    of change:
      change*: ChangeEvent
    of blur:
      blur*: BlurEvent
    of input:
      input*: InputEvent
    of timer: # Triggered periodically, to check and pick any background changes in state
      discard

  OutEventKind* = enum eval, initial_el, update

  OutEvent* = object
    case kind*: OutEventKind
    of eval:
      code*: string
    of initial_el:
      el*: El
    of update:
      diffs*: seq[Diff]

  Component* = ref object of RootObj
    current_tree:   Option[El]
    children:       Table[string, Component]
    children_built: HashSet[string] # Needed to track and destroy old children

method after_create*(self: Component) {.base.} =
  discard

method before_destroy*(self: Component) {.base.} =
  discard

proc after_render*(self: Component) =
  # Removing old child components
  self.children.values.each(after_render)
  let old = self.children.delete((id, child) => id notin self.children_built)
  self.children_built.clear
  old.values.each(before_destroy) # triggering :before_destroy

proc get_child_component*[T](self: Component, _: type[T], id: string): T =
  let full_id = $(T) & "/" & id
  self.children_built.add full_id
  if full_id notin self.children:
    let child = when compiles(T.init): T.init else: T()
    child.after_create
    self.children[full_id] = child
  self.children[full_id].T

template process_in_event*[C](self: C, event: InEvent): bool =
  template if_handler_found(handler_name, code): bool =
    let el = self.current_tree.get.get event.el
    if el.extras.is_some and el.extras_get.`handler_name`.is_some:
      let handler {.inject.} = el.extras_get.`handler_name`.get
      code
      true
    else:
      false

  case event.kind
  of location:
    when compiles(self.on_location(event.location)):
      self.on_location event.location
      true
    else:
      false
  of click:
    if_handler_found on_click:
      handler event.click
  of dblclick:
    if_handler_found on_dblclick:
      handler event.dblclick
  of keydown:
    if_handler_found on_keydown:
      handler event.keydown
  of change:
    if_handler_found on_change:
      handler event.change
  of blur:
    if_handler_found on_blur:
      handler event.blur
  of input:
    # Setting value on binded variable
    let render_for_input_change = block:
      let el = self.current_tree.get.get event.el
      if el.extras.is_some and el.extras_get.set_value.is_some:
        let set_value = el.extras_get.set_value.get
        set_value.handler event.input.value
        not set_value.delay
      else:
        false

    let render_for_input_handler = if_handler_found on_input:
      handler event.input

    render_for_input_change or render_for_input_handler
  of timer:
    when compiles(self.on_timer):
      self.on_timer
    else:
      false

proc process*[C](self: C, events: seq[InEvent], id = ""): seq[OutEvent] =
  let state_changed_maybe = events.map((event) => self.process_in_event event).any
  # Optimisation, skipping render if there's no changes
  if (not state_changed_maybe) and self.current_tree.is_some: return @[]

  # when compiles(self.act): self.act # Do something before render
  let new_tree = self.render
  new_tree.attrs["mono_id"] = id
  self.after_render

  if self.current_tree.is_some:
    let diffs = diff(@[], self.current_tree.get, new_tree)
    unless diffs.is_empty: result.add OutEvent(kind: update, diffs: diffs)
  else:
    result.add OutEvent(kind: initial_el, el: new_tree)
  self.current_tree = new_tree.some

proc get_initial_el*(outbox: seq[OutEvent]): El =
  assert outbox.len == 1 and outbox[0].kind == OutEventKind.initial_el, "initial_el required"
  outbox[0].el