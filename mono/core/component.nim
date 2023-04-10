import base, ext/url, std/macros
import ./helpers

# Types --------------------------------------------------------------------------------------------
type
  SpecialInputKeys* = enum alt, ctrl, meta, shift

  ClickEvent* = object
    keys*: seq[SpecialInputKeys]
  ClickHandler* = proc(e: ClickEvent): void

  KeydownEvent* = object
    key*: int
  KeydownHandler* = proc(e: KeydownEvent): void

  ChangeEvent* = object
    stub*: string # otherwise json doesn't work
  ChangeHandler* = proc(e: ChangeEvent): void

  BlurEvent* = object
    stub*: string # otherwise json doesn't work
  BlurHandler* = proc(e: BlurEvent): void

  InputEvent* = object
    value*: string
  InputHandler* = proc(e: InputEvent): void

  TimeoutEvent* = object
    stub*: string # otherwise json doesn't work

  HtmlElementExtras* = ref object
    # on_focus, on_drag, on_drop, on_keypress, on_keyup
    on_click*:    Option[ClickHandler]
    on_dblclick*: Option[ClickHandler]
    on_keydown*:  Option[KeydownHandler]
    on_change*:   Option[ChangeHandler]
    on_blur*:     Option[BlurHandler]
    on_input*:    Option[InputHandler]
    set_value*:   Option[(proc(v: string): void)]

  HtmlElement* = ref object
    tag*:           string
    attrs*:         JsonNode
    children*:      seq[HtmlElement]
    extras*:        Option[HtmlElementExtras]
    nattrs_cached*: Option[JsonNode]

proc init*(_: type[HtmlElement], tag = "", attrs = new_JObject(), children = seq[HtmlElement].init): HtmlElement =
  HtmlElement(tag: tag, attrs: attrs, children: children)

proc shallow_equal(self, other: HtmlElement): bool =
  # Avoiding attribute normalisation as it's a heavy operation
  self.tag == other.tag and self.attrs == other.attrs and self.children.len == other.children.len


# InEvent ------------------------------------------------------------------------------------------
type InEventType* = enum location, click, dblclick, keydown, change, blur, input, timeout
type InEvent* = object
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


# OutEvent -----------------------------------------------------------------------------------------
type UpdateElement* = ref object
  el*:           seq[int]
  set*:          Option[JsonNode]
  set_attrs*:    Option[Table[string, JsonNode]]
  del_attrs*:    Option[seq[string]]
  set_children*: Option[Table[string, JsonNode]]
  del_children*: Option[seq[int]]

type OutEventType* = enum eval, update_element
type OutEvent* = object
  case kind*: OutEventType
  of eval:
    code*: string
  of update_element:
    updates*: seq[UpdateElement]


# Component ----------------------------------------------------------------------------------------
type Component* = ref object of RootObj
  current_tree:   Option[HtmlElement]
  children:       Table[string, Component]
  children_built: HashSet[string] # Needed to track and destroy old children

method after_create*(self: Component): void {.base.} =
  discard

method before_destroy*(self: Component): void {.base.} =
  discard

# method on_location*(self: Component, path: Url): void {.base.} =
#   discard

# method render*(self: Component): HtmlElement {.base.} =
#   discard

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

proc get*(self: HtmlElement, el_path: seq[int]): HtmlElement

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

proc diff*(id: openarray[int], new_el: HtmlElement, old_el: HtmlElement): seq[UpdateElement]

proc process*[C](self: C, events: seq[InEvent], id = ""): seq[OutEvent] =
  let state_changed_maybe = events.any((event) => self.process_in_event event)
  if (not state_changed_maybe) and self.current_tree.is_some: return @[]

  var new_tree: HtmlElement = self.render
  new_tree.attrs["mono"] = true.to_json
  if not id.is_empty: new_tree.attrs["mono_id"] = id.to_json
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
proc nattrs*(self: HtmlElement): JsonNode =
  # Normalised attributes. HtmlElement stores attributes in shortcut format,
  # like`"tag: ul.todos checked"`, normalisation delayed to improve performance.
  if self.nattrs_cached.is_none:
    let nattrs = self.attrs.copy
    for k, v in parse_tag(self.tag):
      if k in nattrs:
        if k == "class":
          nattrs["class"] = (v & " " & nattrs["class"].get_str).to_json
        else:
          throw fmt"can't redefine attribute '{k}'"
      else:
        nattrs[k] = v.to_json
    if "tag" notin nattrs: nattrs["tag"] = "div".to_json
    self.nattrs_cached = nattrs.some
  return self.nattrs_cached.get

test "nattrs":
  check HtmlElement.init(tag = "ul.todos", attrs = (class: "editing").to_json).nattrs ==
    """{"class":"todos editing","tag":"ul"}""".parse_json

proc get*(self: HtmlElement, el_path: seq[int]): HtmlElement =
  result = self
  for i in el_path:
    result = result.children[i]

proc to_json_hook*(self: HtmlElement): JsonNode =
  var json = if self.children.is_empty:
    self.nattrs.sort
  else:
    self.nattrs.sort.alter((attrs: JsonNode) => (attrs["children"] = self.children.to_json))
  if "tag" in json and json["tag"].get_str == "div": json.delete "tag"
  json

proc diff*(id: openarray[int], new_el: HtmlElement, old_el: HtmlElement): seq[UpdateElement] =
  # Using shallow_equal to avoid attribute normalisation as it's a heavy operation
  if new_el.shallow_equal(old_el):
    for i, new_child in new_el.children:
      let old_child = old_el.children[i]
      result.add diff(id & [i], new_child, old_child)
    return

  let update = UpdateElement(el: id.to_seq)
  result.add update

  let (new_attrs, old_attrs) = (new_el.nattrs, old_el.nattrs)
  block: # tag
    if new_attrs["tag"] != old_attrs["tag"]:
      update.set = new_el.to_json.some
      return

  block: # Attrs
    var set_attrs: Table[string, JsonNode]
    for k, v in new_attrs:
      if k notin old_attrs or v != old_attrs[k]:
        set_attrs[k] = v

    var del_attrs: seq[string]
    for k, v in old_attrs:
      if k notin new_attrs:
        del_attrs.add k

    if not set_attrs.is_empty: update.set_attrs = set_attrs.some
    if not del_attrs.is_empty: update.del_attrs = del_attrs.some

  block: # Children
    var set_children: Table[string, JsonNode]
    for i, new_child in new_el.children:
      if i > old_el.children.high:
        set_children[$i] = new_child.to_json
      else:
        let old_child = old_el.children[i]
        if (not new_child.shallow_equal(old_child)) and (new_child.nattrs["tag"] != old_child.nattrs["tag"]):
          # If tag is different replacing
          set_children[$i] = new_child.to_json
        else:
          result.add diff(id & [i], new_child, old_child)

    var del_children: seq[int]
    if new_el.children.len < old_el.children.len:
      del_children = ((new_el.children.high + 1)..old_el.children.high).to_seq

    if not set_children.is_empty: update.set_children = set_children.some
    if not del_children.is_empty: update.del_children = del_children.some