import base, ext/url
import ./mono_el, ./macro_helpers

export macro_helpers

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
    children*:      Table[string, Component]
    children_built: HashSet[string] # Needed to track and destroy old children

method before_destroy*(self: Component) {.base.} =
  discard

proc after_render(self: Component) =
  # Removing old child components
  self.children.values.each(after_render)
  let old = self.children.delete((id, child) => id notin self.children_built)
  self.children_built.clear
  old.values.each(before_destroy) # triggering :before_destroy

proc set_location[T: Component](component: T, location: Url): bool =
  when compiles(component.on_location(location)):
    component.on_location location
    true
  else:
    false

template process_in_event[T: Component](self: T, current_tree: Option[El], event: InEvent): bool =
  template if_handler_found(handler_name, code: untyped): bool =
    assert current_tree.is_some, "UI tree should be present at this stage"
    let el = current_tree.get.get event.el
    if el.extras.is_some and el.extras_get.`handler_name`.is_some:
      let handler {.inject.} = el.extras_get.`handler_name`.get
      code
      true
    else:
      false

  let state_changed_maybe = case event.kind
  of location:
    set_location(self, event.location)
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
    when compiles(self.on_timer): self.on_timer
    else:                         true

  when compiles(self.after_in_event(event)):
    # Could be needed to update location that depends on input, after the input event.
    # For example, search input, also changes location, and location used in router during rendering.
    if state_changed_maybe: self.after_in_event(event)

  state_changed_maybe

proc process*[T: Component](self: T, current_el: Option[El], events: openarray[InEvent]): Option[El] =
  let state_changed_maybe = events.mapit(self.process_in_event(current_el, it)).any
  if current_el.is_some and not state_changed_maybe: return # Optimisation, skipping render if there's no changes

  # when compiles(self.act): self.act # Do something before render
  let el = self.render
  el.window_location.applyit: discard set_location(self, it) # If location changed, updating
  self.after_render
  el.some

# stateful child components ------------------------------------------------------------------------
proc get*[T: Component](self: Component, _: type[T], id: string | int, set_attrs: (proc(c: T))): T =
  let full_id = $(T) & "/" & id.to_s
  if full_id in self.children_built: throw fmt"Two components have same id: {full_id}"
  self.children_built.add full_id
  if full_id notin self.children:
    let child: T = when compiles(T.init): T.init else: T()
    set_attrs(child)
    when compiles(child.after_create): child.after_create
    self.children[full_id] = child
  self.children[full_id].T

template get*[T: Component](self: Component, TT: type[T], id: string | int, attrs: tuple): T =
  get(self, TT, id, proc(c: T) = c.component_set_attrs(attrs))

template get*[T: Component](self: Component, TT: type[T], attrs: tuple): T =
  get(self, TT, "", proc(c: T) = c.component_set_attrs(attrs))