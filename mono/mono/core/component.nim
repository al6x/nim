import base, ext/url
import ./mono_el, ./macro_helpers

export macro_helpers

type
  Component* = ref object of RootObj
    children*:      Table[string, Component]
    children_built: HashSet[string] # Needed to track and destroy old children

  InEvent* = JsonNode
  LocationInEvent* = tuple[kind: string, location: Url]
  TimerInEvent*    = tuple[kind: string]
  OtherInEvent*    = tuple[kind: string, el: seq[int], event: JsonNode]

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

proc process_in_event[T: Component](self: T, current_tree: Option[El], raw_event: InEvent): bool =
  let kind = raw_event["kind"].get_str
  case kind
  of "location":
    set_location(self, raw_event.json_to(LocationInEvent).location)
  of "timer":
    when compiles(self.on_timer): self.on_timer
    else:                         true
  else:
    let event = raw_event.json_to OtherInEvent
    let el = current_tree.ensure("UI tree should be present at this stage").get event.el
    let el_handlers = el.extras.ensure("element expected to have handlers").MonoElExtras.handlers
    let handlers: seq[MonoHandler] = el_handlers.ensure(kind, "element expected to have handler " & kind)
    for (handler, _) in handlers: handler(event.event)
    handlers.anyit(it.render)

  # when compiles(self.after_in_event(event)):
  #   # Could be needed to update location that depends on input, after the input event.
  #   # For example, search input, also changes location, and location used in router during rendering.
  #   if state_changed_maybe: self.after_in_event(event)

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
    child
  else:
    let child: T = self.children[full_id].T
    set_attrs(child)
    child

template get*[T: Component](self: Component, TT: type[T], id: string | int, attrs: tuple): T =
  get(self, TT, id, proc(c: T) = c.component_set_attrs(attrs))

template get*[T: Component](self: Component, TT: type[T], attrs: tuple): T =
  get(self, TT, "", proc(c: T) = c.component_set_attrs(attrs))