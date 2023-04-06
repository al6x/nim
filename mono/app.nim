import base, ext/url, std/macros
import ./helpers

# Types --------------------------------------------------------------------------------------------
type
  SpecialInputKeys* = enum alt, ctrl, meta, shift

  Location* = object
    path*:  seq[string]
    query*: Table[string, string]

  ClickEvent* = object
    id*:   string
    keys*: seq[SpecialInputKeys]
  ClickHandler* = proc(e: ClickEvent): void

  KeydownEvent* = object
    key*: int
  KeydownHandler* = proc(e: KeydownEvent): void

  ChangeEvent* = object
  ChangeHandler* = proc(e: ChangeEvent): void

  BlurEvent* = object
  BlurHandler* = proc(e: BlurEvent): void

  HtmlElementExtras* = ref object
    on_click*:    Option[ClickHandler]
    on_dblclick*: Option[ClickHandler]
    on_keydown*:  Option[KeydownHandler]
    on_change*:   Option[ChangeHandler]
    on_blur*:     Option[BlurHandler]
    bind_string_value*: Option[(proc(v: string): void)]
    bind_bool_value*:   Option[(proc(v: bool): void)]

  HtmlElement* = ref object
    tag*:           string
    attrs*:         JsonNode
    children*:      seq[HtmlElement]
    extras*:        Option[HtmlElementExtras]
    nattrs_cached*: Option[JsonNode]

# InEvent ------------------------------------------------------------------------------------------
type InEventType* = enum location, click
type InEvent* = object
  case kind*: InEventType
  of location:
    location*: Location
  of click:
    click*: ClickEvent


# OutEvent -----------------------------------------------------------------------------------------
type UpdateAttrsCommand* = object
  set*: Option[Table[string, string]]
  del*: Option[seq[string]]

type MoveChildcommand* = object
  id*:    string
  after*: Option[string] # id of element it should be after, if not defined it will be first

type AddChildcommand* = object
  id*:    string
  after*: Option[string] # id of element it should be after, if not defined it will be first

type UpdateChildreneCommand* = object
  del*:  Option[seq[string]]
  move*: Option[seq[MoveChildcommand]]
  add*:  Option[seq[AddChildcommand]]

type OutEventType* = enum update_document, update_element
type OutEvent* = object
  case kind*: OutEventType
  of update_document:
    title*:    Option[string]
    location*: Option[string]
  of update_element:
    id*:       string
    attrs*:    Option[UpdateAttrsCommand]
    children*: Option[UpdateChildreneCommand]
    elements*: Option[seq[JsonNode]] # List of new Elements


# Component ----------------------------------------------------------------------------------------
type Component* = ref object of RootObj
  children:        Table[string, Component]
  children_built*: HashSet[string] # Needed to track and destroy old children

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
  check HtmlElement(tag: "ul.todos", attrs: (class: "editing").to_json).nattrs ==
    """{"class":"todos editing","tag":"ul"}""".parse_json

proc to_json_hook*(self: HtmlElement): JsonNode =
  if self.children.is_empty:
    self.nattrs
  else:
    self.nattrs.copy.alter((attrs: JsonNode) => (attrs["children"] = self.children.to_json))


# # App ----------------------------------------------------------------------------------------------
# type App* = ref object of RootObj
#   # App represents both window.document and window.document.body
#   title*:            string
#   location*:         Location
#   attrs*:            Table[string, string] # attrs of document.body
#   children*:         seq[Element]          # children of document.body
#   on_click_handler*: Option[proc(e: ClickEvent): void]

# method process*(self: App, event: InEvent): seq[OutEvent] =
#   throw "not implemented"

# method on_create*(self: App): void {.base.} = discard
# method on_destroy*(self: App): void {.base.} = discard


# # Apps ---------------------------------------------------------------------------------------------
# type Apps* = ref Table[string, proc: App]

# proc build*(self: Apps, url: Url): App =
#   # Returns app and initial events, like going to given url
#   let id = if url.host == "localhost": url.query.ensure("_app", "_app query parameter required") else: url.host
#   self[].ensure(id, fmt"Error, unknown application '{id}'")()




# # # if is_main_module:


# # # type HElement* = ref object
# # #   tag*:       string
# # #   attrs*:     Table[string, string]
# # #   children*:  seq[HElement]

# # # type HApp* = ref object
# # #   title*:       string
# # #   location*:    Location
# # #   attrs*:       Table[string, string]
# # #   children*:    seq[HElement]