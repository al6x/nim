import base, ext/html

type
  SpecialInputKeys* = enum alt, ctrl, meta, shift

  ClickEvent* = object
    special_keys*: seq[SpecialInputKeys]
  ClickHandler* = proc(e: ClickEvent)

  KeydownEvent* = object
    key*:          string
    special_keys*: seq[SpecialInputKeys]
  KeydownHandler* = proc(e: KeydownEvent)

  ChangeEvent* = object
    stub*: string # otherwise json doesn't work
  ChangeHandler* = proc(e: ChangeEvent)

  BlurEvent* = object
    stub*: string # otherwise json doesn't work
  BlurHandler* = proc(e: BlurEvent)

  InputEvent* = object
    value*: string
  InputHandler* = proc(e: InputEvent)

  SetValueHandler* = object
    handler*: (proc(v: string))
    delay*:   bool # Performance optimisation, if set to true it won't cause re-render

  ElExtras* = ref object
    # on_focus, on_drag, on_drop, on_keypress, on_keyup
    on_click*:    Option[ClickHandler]
    on_dblclick*: Option[ClickHandler]
    on_keydown*:  Option[KeydownHandler]
    on_change*:   Option[ChangeHandler]
    on_blur*:     Option[BlurHandler]
    on_input*:    Option[InputHandler]
    set_value*:   Option[SetValueHandler]

  El* = ref object
    tag*:           string
    attrs*:         JsonNode
    children*:      seq[El]
    extras*:        Option[ElExtras]
    nattrs_cached*: Option[JsonNode]

  UpdateElement* = ref object
    el*:           seq[int]
    set*:          Option[JsonNode]
    set_attrs*:    Option[Table[string, JsonNode]]
    del_attrs*:    Option[seq[string]]
    set_children*: Option[Table[string, JsonNode]]
    del_children*: Option[seq[int]]

proc init*(_: type[El], tag = "", attrs = new_JObject(), children = seq[El].init): El =
  El(tag: tag, attrs: attrs, children: children)

proc shallow_equal(self, other: El): bool =
  # Avoiding attribute normalisation as it's a heavy operation
  self.tag == other.tag and self.attrs == other.attrs and self.children.len == other.children.len

const special    = {'#', '.', '$'}
const delimiters = special + {' '}
proc parse_tag*(s: string): Table[string, string] =
  # Parses `"span#id.c1.c2 type=checkbox required"`

  proc consume_token(i: var int): string =
    var token = ""
    while i < s.len and s[i] notin delimiters:
      token.add s[i]
      i.inc
    token

  # skipping space
  var i = 0
  proc skip_space =
    while i < s.len and s[i] == ' ': i.inc
  skip_space()

  # tag
  if i < s.len and s[i] notin delimiters:
    result["tag"] = consume_token i
  skip_space()

  # component, id, class
  var classes: seq[string]
  while i < s.len and s[i] in special:
    i.inc

    case s[i-1]
    of '$': result["c"] = consume_token i  # component
    of '#': result["id"] = consume_token i # id
    of '.': classes.add consume_token(i)   # class
    else:   throw "internal error"
    skip_space()

  if not classes.is_empty: result["class"] = classes.join(" ")

  # attrs
  var attr_tokens: seq[string]
  while true:
    skip_space()
    if i == s.len: break
    let token = consume_token(i)
    if token.is_empty: break
    attr_tokens.add token

  if not attr_tokens.is_empty:
    for token in attr_tokens:
      let tokens = token.split "="
      if tokens.len > 2: throw fmt"invalid attribute '{token}'"
      result[tokens[0]] = if tokens.len > 1: tokens[1] else: "true"

proc nattrs*(self: El): JsonNode =
  # Normalised attributes. El stores attributes in shortcut format,
  # like`"tag: ul.todos checked"`, normalisation delayed to improve performance.
  if self.nattrs_cached.is_none:
    let nattrs = self.attrs.copy
    for k, v in parse_tag(self.tag):
      if k in nattrs:
        case k
        of "class": nattrs["class"] = (v & " " & nattrs["class"].get_str).to_json
        else:       throw fmt"can't redefine attribute '{k}' for '{self.attrs}'"
      else:
        nattrs[k] = v.to_json
    if "tag" notin nattrs: nattrs["tag"] = "div".to_json
    if "c" in nattrs:
      let class = if "class" in nattrs: nattrs["class"].get_str else: ""
      let delimiter = if class.is_empty: "" else: " "
      nattrs["class"] = (nattrs["c"].get_str & " C" & delimiter & class).to_json
    self.nattrs_cached = nattrs.sort.some
  return self.nattrs_cached.get

proc get*(self: El, el_path: seq[int]): El =
  result = self
  for i in el_path:
    result = result.children[i]

# Different HTML inputs use different attributes for value
proc normalise_value*(el: JsonNode) =
  let tag = if "tag" in el: el["tag"].get_str else: "div"
  if tag == "input" and "type" in el and el["type"].get_str == "checkbox":
    let value = el["value"]
    el.delete "value"
    assert value.kind == JBool, "checkbox should have boolean value type"
    if value.get_bool:
      el["checked"] = true.to_json

proc to_json_hook*(self: El): JsonNode =
  var json = if self.children.is_empty:
    self.nattrs.sort
  else:
    # p self.tag
    self.nattrs.sort.alter((attrs: JsonNode) => (attrs["children"] = self.children.to_json))

  if "tag" in json and json["tag"].get_str == "div": json.delete "tag"

  if "value" in json: json.normalise_value

  if self.extras.is_some:
    if self.extras.get.on_click.is_some:    json["on_click"] = true.to_json
    if self.extras.get.on_dblclick.is_some: json["on_dblclick"] = true.to_json
    if self.extras.get.on_keydown.is_some:  json["on_keydown"] = true.to_json
    if self.extras.get.on_change.is_some:   json["on_change"] = true.to_json
    if self.extras.get.on_blur.is_some:     json["on_blur"] = true.to_json
    if self.extras.get.on_input.is_some:    json["on_input"] = true.to_json

  json

proc diff*(id: openarray[int], old_el, new_el: El): seq[UpdateElement] =
  # Using shallow_equal to avoid attribute normalisation as it's a heavy operation
  if new_el.shallow_equal(old_el):
    for i, new_child in new_el.children:
      let old_child = old_el.children[i]
      result.add diff(id & [i], old_child, new_child)
    return

  let update = UpdateElement(el: id.to_seq)
  result.add update

  let (new_attrs, old_attrs) = (new_el.nattrs, old_el.nattrs)
  if "value" in new_attrs: new_attrs.normalise_value
  if "value" in old_attrs: old_attrs.normalise_value

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
          result.add diff(id & [i], old_child, new_child)

    var del_children: seq[int]
    if new_el.children.len < old_el.children.len:
      del_children = ((new_el.children.high + 1)..old_el.children.high).to_seq

    if not set_children.is_empty: update.set_children = set_children.some
    if not del_children.is_empty: update.del_children = del_children.some


# to_html ------------------------------------------------------------------------------------------
proc escape_html_text(s: string): SafeHtml = s.escape_html
proc escape_html_attr_name(name: string): SafeHtml = name.escape_html
proc escape_html_attr_value(v: JsonNode): SafeHtml =
  # (if v.kind == JString: "\"" & v.get_str.escape_html & "\"" else: v.to_s(false).escape_html)
  "\"" & (if v.kind == JString: v.get_str.escape_html else: v.to_s(false).escape_html) & "\""

proc to_html*(el: JsonNode, indent = "", comments = false): string =
  assert el.kind == JObject, "to_html element data should be JObject"
  if comments and "c" in el:
    result.add "\n" & indent & fmt"""<!-- {el["c"].get_str.escape_html_text} -->""" & "\n"
  let tag = if "tag" in el: el["tag"].get_str else: "div"
  var attr_tokens: seq[string]
  let el = el.sort
  for k, v in el.fields:
    if k in ["c", "tag", "children", "text", "html"]: continue
    attr_tokens.add k.escape_html_attr_name & "=" & v.escape_html_attr_value
  result.add indent & "<" & tag
  if not attr_tokens.is_empty:
    result.add " " & attr_tokens.join(" ")
  result.add ">"
  if "text" in el:
    assert "children" notin el, "to_html doesn't support both text and children"
    assert "html"     notin el, "to_html doesn't support both text and html"
    let safe_text = if el["text"].kind == JString:
      el["text"].get_str.escape_html_text
    else:
      el["text"].to_s(false).escape_html_text
    result.add safe_text & "</" & tag & ">"
  elif "html" in el:
    assert "children" notin el, "to_html doesn't support both html and children"
    assert el["html"].kind == JString, "html should be string"
    result.add "" & el["html"].get_str & "</" & tag & ">"
  elif "children" in el:
    let children = el["children"]
    assert children.kind == JArray, "to_html element children should be JArray"
    result.add "\n"
    for v in children:
      result.add v.to_html(indent = indent & "  ", comments = comments) & "\n"
    result.add indent & "</" & tag & ">"
  else:
    # result.add "/>"
    result.add "</" & tag & ">"
  if comments and "c" in el:
    result.add "\n"
  result = result.replace(re"\n\n\n", "\n\n")

proc to_html*(el: El, indent = "", comments = false): string =
  el.to_json.to_html(indent = indent, comments = comments)

proc to_html*(els: openarray[El], indent = "", comments = false): string =
  els.map((el) => el.to_html(indent = indent, comments = comments)).join("\n").replace(re"\n\n\n", "\n\n")

proc window_title*(el: JsonNode): string =
  assert el.kind == JObject, "to_html element data should be JObject"
  if "window_title" in el: el["window_title"].get_str else: ""

# attrs --------------------------------------------------------------------------------------------
proc attr*[T](self: El, k: string, v: T) =
  self.attrs[k] = v.to_json

proc value*[T](self: El, v: T) =
  self.attr("value", v)

proc text*[T](self: El, text: T) =
  self.attr("text", text)

proc style*(self: El, style: string) =
  self.attr("style", style)

proc class*(self: El, class: string) =
  let class = if "class" in self.attrs: self.attrs["class"].get_str & " " & class else: class
  self.attr "class", class

proc location*[T](self: El, location: T) =
  self.attr("href", location.to_s)

proc window_title*(self: El, title: string) =
  self.attr("window_title", title)

proc window_location*[T](self: El, location: T) =
  self.attr("window_location", location.to_s)

# events -------------------------------------------------------------------------------------------
proc extras_getset*(self: El): ElExtras =
  if self.extras.is_none: self.extras = ElExtras().some
  self.extras.get

proc init*(_: type[SetValueHandler], handler: (proc(v: string)), delay: bool): SetValueHandler =
  SetValueHandler(handler: handler, delay: delay)

template bind_to*(element: El, variable, delay) =
  let el = element
  el.value variable

  el.extras_getset.set_value = SetValueHandler.init(
    (proc(v: string) {.closure.} =
      variable = typeof(variable).parse v
      el.attrs["value"] = variable.to_json # updating value on the element, to avoid it being detected by diff
    ),
    delay
  ).some

template bind_to*(element: El, variable) =
  bind_to(element, variable, false)

proc on_click*(self: El, fn: proc(e: ClickEvent)) =
  self.extras_getset.on_click = fn.some

proc on_click*(self: El, fn: proc()) =
  self.extras_getset.on_click = (proc(e: ClickEvent) = fn()).some

proc on_dblclick*(self: El, fn: proc(e: ClickEvent)) =
  self.extras_getset.on_dblclick = fn.some

proc on_dblclick*(self: El, fn: proc()) =
  self.extras_getset.on_dblclick = (proc(e: ClickEvent) = fn()).some

proc on_keydown*(self: El, fn: proc(e: KeydownEvent)) =
  self.extras_getset.on_keydown = fn.some

proc on_change*(self: El, fn: proc(e: ChangeEvent)) =
  self.extras_getset.on_change = fn.some

proc on_blur*(self: El, fn: proc(e: BlurEvent)) =
  self.extras_getset.on_blur = fn.some

proc on_blur*(self: El, fn: proc()) =
  self.extras_getset.on_blur = (proc(e: BlurEvent) = fn()).some