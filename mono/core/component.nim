import base, ext/url, std/macros
import ./html_element

type
  InEventType* = enum location, click, dblclick, keydown, change, blur, input, timeout

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
    of timeout:
      discard

  OutEventType* = enum eval, update_element

  OutEvent* = object
    case kind*: OutEventType
    of eval:
      code*: string
    of update_element:
      updates*: seq[UpdateElement]

  Component* = ref object of RootObj
    current_tree:   Option[HtmlElement]
    children:       Table[string, Component]
    children_built: HashSet[string] # Needed to track and destroy old children

method after_create*(self: Component): void {.base.} =
  discard

method before_destroy*(self: Component): void {.base.} =
  discard

proc after_render*(self: Component): void =
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

proc get_child_component*[T](
  self: Component, ChildT: type[T], id: string, set_attrs: (proc(component: T): void)
): T =
  let child = self.get_child_component(ChildT, id)
  child.set_attrs # setting on new or overriding attributes on existing children
  child

template process_in_event*[C](self: C, event: InEvent): bool =
  template if_handler_found(handler_name, code): bool =
    let el = self.current_tree.get.get event.el
    if el.extras.is_some and el.extras.get.`handler_name`.is_some:
      let handler {.inject.} = el.extras.get.`handler_name`.get
      code
      true
    else:
      false

  case event.kind
  of location:
    when compiles(self.on_location event.location):
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
    let el = self.current_tree.get.get event.el
    if el.extras.is_some and el.extras.get.set_value.is_some:
      let set_value = el.extras.get.set_value.get
      set_value event.input.value

    if_handler_found on_input:
      handler event.input
  of timeout:
    true

proc process*[C](self: C, events: seq[InEvent], id = ""): seq[OutEvent] =
  let state_changed_maybe = events.any((event) => self.process_in_event event)
  if (not state_changed_maybe) and self.current_tree.is_some: return @[]

  var new_tree: HtmlElement = self.render
  new_tree.attrs["mono_id"] = id.to_json
  # # Root always should be document, auto creating if it's not
  # if new_tree.nattrs["tag"].get_str != "document":
  #   new_tree = HtmlElement.init(tag = "document", children = @[new_tree])
  self.after_render

  let updates = if self.current_tree.is_some:
    diff(@[], new_tree, self.current_tree.get)
  else:
    @[UpdateElement(el: @[], set: new_tree.to_json.some)]
  self.current_tree = new_tree.some

  @[OutEvent(kind: update_element, updates: updates)]


# HtmlElement --------------------------------------------------------------------------------------
proc initial_html_el*(events: seq[OutEvent]): JsonNode =
  assert events.len == 1, "to_html can't convert more than single event"
  assert events[0].kind == update_element, "to_html can't convert event other than update_element"
  assert events[0].updates.len == 1, "to_html can't convert more than single update"
  let update = events[0].updates[0]
  assert update.el == @[], "to_html can convert only root element"
  assert (
    update.set_attrs.is_none and update.del_attrs.is_none and
    update.set_children.is_none and update.del_children.is_none
  ), "to_html requires all changes other than `set` be empty"
  assert update.set.is_some, "to_html the `set` required"
  update.set.get