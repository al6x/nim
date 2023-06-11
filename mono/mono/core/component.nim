import base, std/macros, ext/url
import ./mono_el

type
  InEventType* = enum location, click, dblclick, keydown, change, blur, input, timer

  InEvent* = object
    el*: seq[int]
    case kind*: InEventType
    of location: location*: Url
    of click:    click*: ClickEvent
    of dblclick: dblclick*: ClickEvent
    of keydown:  keydown*: KeydownEvent
    of change:   change*: ChangeEvent
    of blur:     blur*: BlurEvent
    of input:    input*: InputEvent
    of timer:    discard # Triggered periodically, to check and pick any background changes in state

  Component* = ref object of RootObj
    children:       Table[string, Component]
    children_built: HashSet[string] # Needed to track and destroy old children

method before_destroy*(self: Component) {.base.} =
  discard

proc after_render(self: Component) =
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
    when compiles(child.after_create): child.after_create
    self.children[full_id] = child
  self.children[full_id].T

template process_in_event[C](self: C, current_tree: Option[El], event: InEvent): bool =
  template if_handler_found(handler_name, code): bool =
    assert current_tree.is_some, "UI tree should be present at this stage"
    let el = current_tree.get.get event.el
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
    if_handler_found on_click, handler(event.click)
  of dblclick:
    if_handler_found on_dblclick, handler(event.dblclick)
  of keydown:
    if_handler_found on_keydown, handler(event.keydown)
  of change:
    if_handler_found on_change, handler(event.change)
  of blur:
    if_handler_found on_blur, handler(event.blur)
  of input:
    # Setting value on binded variable
    let render_for_input_change = block:
      assert current_tree.is_some, "UI tree should be present at this stage"
      let el = current_tree.get.get event.el
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

proc process*[C](self: C, current_el: Option[El], events: openarray[InEvent]): Option[El] =
  let state_changed_maybe = events.mapit(self.process_in_event(current_el, it)).any
  if current_el.is_some and not state_changed_maybe: return # Optimisation, skipping render if there's no changes

  # when compiles(self.act): self.act # Do something before render
  let el = self.render
  self.after_render
  el.some