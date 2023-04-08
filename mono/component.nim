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
  ChangeHandler* = proc(e: ChangeEvent): void

  BlurEvent* = object
  BlurHandler* = proc(e: BlurEvent): void

  InputEvent* = object
    value*: string
  InputHandler* = proc(e: InputEvent): void

  TimeoutEvent* = object

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
type UpdateAttrsCommand* = object
  set*: Option[Table[string, string]]
  del*: Option[seq[string]]

type MoveChildcommand* = object
  i*:     int
  after*: Option[int] # id of element it should be after, if not defined it will be first

type AddChildcommand* = object
  after*: Option[int] # id of element it should be after, if not defined it will be first
  el*:    JsonNode

type UpdateChildCommand* = object
  del*:  Option[seq[int]]
  move*: Option[seq[MoveChildcommand]]
  add*:  Option[seq[AddChildcommand]]

type OutEventType* = enum eval, update_element
type OutEvent* = object
  case kind*: OutEventType
  of eval:
    code*: string
  of update_element:
    id*:       seq[int]
    attrs*:    Option[UpdateAttrsCommand]
    children*: Option[UpdateChildCommand]


# Component ----------------------------------------------------------------------------------------
type Component* = ref object of RootObj
  previous_tree:  Option[HtmlElement]
  children:       Table[string, Component]
  children_built: HashSet[string] # Needed to track and destroy old children

method after_create*(self: Component): void {.base.} =
  discard

method before_destroy*(self: Component): void {.base.} =
  discard

method on_location*(self: Component, path: Url): void {.base.} =
  discard

method render*(self: Component): HtmlElement {.base.} =
  discard

proc after_render*(self: Component): void =
  # Removing old child components
  self.children.values.each(after_render)
  let old = self.children.delete((id, child) => id notin self.children_built)
  self.children_built.clear
  old.values.each(before_destroy) # triggering :before_destroy

proc get_child_component*[T](self: Component, _: type[T], id: string, set_attrs: (proc(component: T): void)): T =
  let full_id = $(T) & "/" & id
  self.children_built.add full_id
  if full_id notin self.children:
    let child = when compiles(T.init): T.init else: T()
    child.after_create
    self.children[full_id] = child
  let child = self.children[full_id].T
  child.set_attrs # setting on new or overriding attributes on existing children
  child

proc get_element(self: Component, el_path: seq[int]): HtmlElement

proc process_in_event*(self: Component, event: InEvent): bool =
  template if_handler_found(handler_name, code): bool =
    let el = self.get_element event.el
    if el.extras.is_some and el.extras.get.`handler_name`.is_some:
      let handler {.inject.} = el.extras.get.`handler_name`.get
      code
      true
    else:
      false

  case event.kind
  of location:
    self.on_location event.location
    true
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
    let el = self.get_element event.el
    if el.extras.is_some and el.extras.get.set_value.is_some:
      let set_value = el.extras.get.set_value.get
      set_value event.input.value

    if_handler_found on_input:
      handler event.input
  of timeout:
    true

proc process*(self: Component, events: seq[InEvent]): seq[OutEvent] =
  let state_changed_maybe = events.any((event) => self.process_in_event event)
  if not state_changed_maybe: return @[]

  let tree = self.render





  #   HtmlElementExtras* = ref object
  #   # on_focus, on_drag, on_drop, on_keypress, on_keyup
  #   on_click*:    Option[ClickHandler]
  #   on_dblclick*: Option[ClickHandler]
  #   on_keydown*:  Option[KeydownHandler]
  #   on_change*:   Option[ChangeHandler]
  #   on_blur*:     Option[BlurHandler]
  #   set_value*:   Option[(proc(v: string): void)]

  # HtmlElement* = ref object
  #   tag*:           string
  #   attrs*:         JsonNode
  #   children*:      seq[HtmlElement]
  #   extras*:        Option[HtmlElementExtras]
  #   nattrs_cached*: Option[JsonNode]



# HtmlElement --------------------------------------------------------------------------------------
proc get_element(self: Component, el_path: seq[int]): HtmlElement =
  discard

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
  check HtmlElement(tag: "ul.todos", attrs: (class: "editing").to_json).nattrs ==
    """{"class":"todos editing","tag":"ul"}""".parse_json

proc to_json_hook*(self: HtmlElement): JsonNode =
  if self.children.is_empty:
    self.nattrs
  else:
    self.nattrs.copy.alter((attrs: JsonNode) => (attrs["children"] = self.children.to_json))


# # Apps ---------------------------------------------------------------------------------------------
# type Apps* = ref Table[string, proc: App]

# proc build*(self: Apps, url: Url): App =
#   # Returns app and initial events, like going to given url
#   let id = if url.host == "localhost": url.query.ensure("_app", "_app query parameter required") else: url.host
#   self[].ensure(id, fmt"Error, unknown application '{id}'")()