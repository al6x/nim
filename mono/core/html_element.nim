import base

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

  HtmlElementExtras* = ref object
    # on_focus, on_drag, on_drop, on_keypress, on_keyup
    on_click*:    Option[ClickHandler]
    on_dblclick*: Option[ClickHandler]
    on_keydown*:  Option[KeydownHandler]
    on_change*:   Option[ChangeHandler]
    on_blur*:     Option[BlurHandler]
    on_input*:    Option[InputHandler]
    set_value*:   Option[SetValueHandler]

  HtmlElement* = ref object
    tag*:           string
    attrs*:         JsonNode
    children*:      seq[HtmlElement]
    extras*:        Option[HtmlElementExtras]
    nattrs_cached*: Option[JsonNode]

  UpdateElement* = ref object
    el*:           seq[int]
    set*:          Option[JsonNode]
    set_attrs*:    Option[Table[string, JsonNode]]
    del_attrs*:    Option[seq[string]]
    set_children*: Option[Table[string, JsonNode]]
    del_children*: Option[seq[int]]


proc init*(_: type[HtmlElement], tag = "", attrs = new_JObject(), children = seq[HtmlElement].init): HtmlElement =
  HtmlElement(tag: tag, attrs: attrs, children: children)

proc shallow_equal(self, other: HtmlElement): bool =
  # Avoiding attribute normalisation as it's a heavy operation
  self.tag == other.tag and self.attrs == other.attrs and self.children.len == other.children.len

proc parse_tag*(expression: string): Table[string, string] =
  # Parses `"span#id.c1.c2 type=checkbox required"`
  let delimiters = {'#', ' ', '.'}

  proc consume_token(i: var int): string =
    var token = ""
    while i < expression.len and expression[i] notin delimiters:
      token.add expression[i]
      i += 1
    token

  # tag
  var i = 0
  if i < expression.len and expression[i] notin delimiters:
    result["tag"] = consume_token i

  # id
  if i < expression.len and expression[i] == '#':
    i += 1
    result["id"] = consume_token i

  # class
  var classes: seq[string]
  while i < expression.len and expression[i] == '.':
    i += 1
    classes.add consume_token(i)
  if not classes.is_empty: result["class"] = classes.join(" ")

  # other attrs
  var attr_tokens: seq[string]
  while i < expression.len and expression[i] == ' ':
    i += 1
    attr_tokens.add consume_token(i)
  if not attr_tokens.is_empty:
    for token in attr_tokens:
      let tokens = token.split "="
      if tokens.len > 2: throw fmt"invalid attribute '{token}'"
      result[tokens[0]] = if tokens.len > 1: tokens[1] else: "true"

test "parse_tag":
  template check_attrs(tag: string, expected) =
    check parse_tag(tag) == expected.to_table

  check_attrs "span#id.c1.c2 type=checkbox required", {
    "tag": "span", "id": "id", "class": "c1 c2", "type": "checkbox", "required": "true"
  }
  check_attrs "span", { "tag": "span" }
  check_attrs "#id", { "id": "id" }
  check_attrs ".c1", { "class": "c1" }

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
    self.nattrs_cached = nattrs.sort.some
  return self.nattrs_cached.get

test "nattrs":
  check HtmlElement.init(tag = "ul.todos", attrs = (class: "editing").to_json).nattrs ==
    """{"class":"todos editing","tag":"ul"}""".parse_json

proc get*(self: HtmlElement, el_path: seq[int]): HtmlElement =
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

proc to_json_hook*(self: HtmlElement): JsonNode =
  var json = if self.children.is_empty:
    self.nattrs.sort
  else:
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
          result.add diff(id & [i], new_child, old_child)

    var del_children: seq[int]
    if new_el.children.len < old_el.children.len:
      del_children = ((new_el.children.high + 1)..old_el.children.high).to_seq

    if not set_children.is_empty: update.set_children = set_children.some
    if not del_children.is_empty: update.del_children = del_children.some

# escape_html, js ----------------------------------------------------------------------------------
const ESCAPE_HTML_MAP = {
  "&": "&amp;",
  "<":  "&lt;",
  ">":  "&gt;",
  "\"": "&quot;",
  "'":  "&#39;"
}.to_table

proc escape_html*(html: string): string =
  html.replace(re"""([&<>'"])""", (c) => ESCAPE_HTML_MAP[c])

test "escape_html":
  check escape_html("""<div attr="val">""") == "&lt;div attr=&quot;val&quot;&gt;"

func escape_js*(js: string): string =
  js.to_json.to_s.replace(re"""^"|"$""", "")

test "escape_js":
  assert escape_js("""); alert("hi there""") == """); alert(\"hi there"""

# to_html ------------------------------------------------------------------------------------------
proc escape_html_text(s: string): string = s.escape_html
proc escape_html_attr_name(name: string): string = name.escape_html
proc escape_html_attr_value(v: JsonNode): string =
  # (if v.kind == JString: "\"" & v.get_str.escape_html & "\"" else: v.to_s(false).escape_html)
  "\"" & (if v.kind == JString: v.get_str.escape_html else: v.to_s(false).escape_html) & "\""


proc to_html*(el: JsonNode, indent = ""): string =
  assert el.kind == JObject, "to_html element data should be JObject"
  let tag = if "tag" in el: el["tag"].get_str else: "div"
  var attr_tokens: seq[string]
  let el = el.sort
  # el.normalise_value
  for k, v in el.fields:
    if k in ["tag", "children", "text"]: continue
    attr_tokens.add k.escape_html_attr_name & "=" & v.escape_html_attr_value
  result.add indent & "<" & tag
  if not attr_tokens.is_empty:
    result.add " " & attr_tokens.join(" ")
  if "text" in el:
    assert "children" notin el, "to_html doesn't support both text and children"
    let safe_text = if el["text"].kind == JString:
      el["text"].get_str.escape_html_text
    else:
      el["text"].to_s(false).escape_html_text
    result.add ">" & safe_text & "</" & tag & ">"
  elif "children" in el:
    let children = el["children"]
    assert children.kind == JArray, "to_html element children should be JArray"
    result.add ">\n"
    for v in children:
      result.add v.to_html(indent & "  ") & "\n"
    result.add indent & "</" & tag & ">"
  else:
    result.add "/>"

proc to_html*(el: HtmlElement): string =
  el.to_json.to_html

test "to_html":
  let el = %{ class: "parent", children: [
    { class: "counter", children: [
      { tag: "input", value: "some", type: "text" },
      { tag: "button", text: "+" },
    ] }
  ] }
  let html = """
    <div class="parent">
      <div class="counter">
        <input type="text" value="some"/>
        <button>+</button>
      </div>
    </div>""".dedent
  check el.to_html == html

  check HtmlElement.init.to_html == "<div/>"

  check (%{ text: 0 }).to_html == "<div>0</div>" # from error

proc to_html_and_document(el: JsonNode): tuple[html: string, document: JsonNode] =
  # If the root element is "document", excluding it from the HTML
  assert el.kind == JObject, "to_html element data should be JObject"
  let tag = if "tag" in el: el["tag"].get_str else: "div"
  if tag == "document":
    let document = el.copy
    document.delete "tag"
    document.delete "children"
    var html = ""
    let children = el["children"]
    assert children.kind == JArray, "to_html element children should be JArray"
    (children.to_seq.map((el) => el.to_html).join("\n"), document)
  else:
    (el.to_html, new_JObject())

proc document_to_meta(document: JsonNode): string =
  assert document.kind == JObject, "document_to_meta document should be JObject"
  var tags: seq[string]
  for k, v in document.sort.fields:
    tags.add "<meta name=\"" & k.escape_html_attr_name & "\" content=" & v.escape_html_attr_value & "/>"
  tags.join("\n")

proc to_meta_html*(el: JsonNode): tuple[meta, html: string] =
  let (html, document) = el.to_html_and_document
  (meta: document.document_to_meta, html: html)

test "to_meta_html":
  let el = %{ tag: "document", title: "some", children: [
    { class: "counter" }
  ] }
  check el.to_meta_html == (
    meta: """<meta name="title" content="some"/>""",
    html: """<div class="counter"/>"""
  )