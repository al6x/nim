import base

# exape_html, exape_js -----------------------------------------------------------------------------
type SafeHtml* = string
# type SafeHtml* = distinct string # not working, Nim crashes https://github.com/nim-lang/Nim/issues/21800

proc escape_html*(html: string, quotes = true): SafeHtml =
  let escape_map {.global.} = { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }.to_table
  let escape_re {.global.} = re"""([&<>'"])"""
  let partial_map {.global.} = { "&": "&amp;", "<": "&lt;", ">": "&gt;" }.to_table
  let partial_re {.global.} = re"""([&<>])"""

  if quotes: html.replace(escape_re, (c) => escape_map[c])
  else:      html.replace(partial_re, (c) => partial_map[c])

test "escape_html":
  check escape_html("""<div attr="val">""").to_s == "&lt;div attr=&quot;val&quot;&gt;"

proc escape_js*(js: string): SafeHtml =
  js.to_json.to_s.replace(re"""^"|"$""", "")

test "escape_js":
  assert escape_js("""); alert("hi there""") == """); alert(\"hi there"""

proc svg_to_url_data*(svg: string): SafeHtml =
  ("data:image/svg+xml,").escape_html(quotes = false)
    .replace("\"", "'") # not necessary, but makes it more nice and shorter

# parse_tag ----------------------------------------------------------------------------------------
proc parse_tag*(s: string): tuple[tag: string, attrs: Table[string, string]] =
  const special = {'#', '.', '$'}
  const delimiters = special + {' '}

  # Parses `"span#id.c1.c2 type=checkbox required"`
  var tag = "div"; var attrs: Table[string, string]

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
    tag = consume_token i
  skip_space()

  # component, id, class
  var classes: seq[string]
  while i < s.len and s[i] in special:
    i.inc

    case s[i-1]
    of '$': attrs["c"] = consume_token i  # component
    of '#': attrs["id"] = consume_token i # id
    of '.': classes.add consume_token(i)   # class
    else:   throw "internal error"
    skip_space()

  if not classes.is_empty: attrs["class"] = classes.join(" ")

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
      attrs[tokens[0]] = if tokens.len > 1: tokens[1] else: "true"

  (tag, attrs)

test "parse_tag":
  template check_attrs(tag: string, expected) =
    check parse_tag(tag) == (expected[0], expected[1].to_table)
  let empty_attrs = seq[(string, string)].init

  check_attrs "span#id.c-1.c2 .c3  .c-4 type=checkbox required", (
    "span", { "id": "id", "class": "c-1 c2 c3 c-4", "type": "checkbox", "required": "true" })

  check_attrs "span",     ("span", empty_attrs)
  check_attrs "#id",      ("div",  { "id": "id" })
  check_attrs ".c-1",     ("div",  { "class": "c-1" })
  check_attrs "div  a=b", ("div",  { "a": "b" })
  check_attrs " .a  a=b", ("div",  { "class": "a", "a": "b" })
  check_attrs " .a",      ("div",  { "class": "a" })

  check_attrs "$controls .a",     ("div",    { "c": "controls", "class": "a" })
  check_attrs "$controls.a",      ("div",    { "c": "controls", "class": "a" })
  check_attrs "button$button.a",  ("button", { "c": "button", "class": "a" })
  check_attrs "block-ft .a",      ("block-ft", { "class": "a" })

# el -----------------------------------------------------------------------------------------------
type
  ElAttrs*  = Table[string, string]
  ElExtras* = ref object of RootObj
  ElKind* = enum el, text, html, list
  El* = ref object
    children*: seq[El]
    case kind*: ElKind
    of el:
      tag*:      string
      attrs*:    ElAttrs
    of text:
      text_data*: string
    of html:
      html_data*: SafeHtml
    of list:
      discard
    extras*: Option[ElExtras] # Integration with other frameworks

  # Normalising inconsistencies in HTML attrs, some should be set as `el.setAttribute(k, v)` some as `el.k = v`.
  ElAttrKind* = enum string_prop, string_attr, bool_prop
  ElAttrVal* = (string, ElAttrKind)

proc init*(_: type[El], tag = ""): El =
  let (tag, attrs) = parse_tag(tag)
  El(kind: ElKind.el, tag: tag, attrs: attrs)

proc html_el*(html: SafeHtml): El =
  El(kind: ElKind.html, html_data: html)

proc text_el*(text: string): El =
  El(kind: ElKind.text, text_data: text)

proc `==`*(self, other: El): bool {.no_side_effect.} =
  if self.kind != other.kind: return false
  case self.kind
  of el:   self.tag == other.tag and self.attrs == other.attrs and self.children == other.children and
             self.extras == self.extras
  of text: self.text_data == other.text_data
  of html: self.html_data == other.html_data
  of list: self.children == other.children

proc dcopy*(self: El): El =
  case self.kind
  of el:   El(kind: el, tag: self.tag, attrs: self.attrs, children: self.children, extras: self.extras)
  of text: El(kind: text, text_data: self.text_data, extras: self.extras)
  of html: El(kind: html, html_data: self.html_data, extras: self.extras)
  of list: El(kind: list, children: self.children, extras: self.extras)

proc contains*(el: El, k: string): bool =
  k in el.attrs

proc `[]`*(el: El, k: string): string =
  el.attrs[k]

proc `[]=`*(el: El, k: string, v: string | int | bool) =
  el.attrs[k] = v.to_s

proc normalize*(el: El): (El, OrderedTable[string, ElAttrVal])

proc to_json_hook*(el: El): JsonNode =
  case el.kind
  of ElKind.el:
    let (nel, nattrs) = el.normalize
    if nel.children.is_empty: %{ kind: el.kind, tag: el.tag, attrs: nattrs }
    else:                     %{ kind: el.kind, tag: el.tag, attrs: nattrs, children: nel.children }
  of ElKind.text:             %{ kind: el.kind, text: el.text_data }
  of ElKind.html:             %{ kind: el.kind, html: el.html_data }
  of ElKind.list:            throw "json for el.list is not implemented"

proc to_html*(el: El, html: var SafeHtml, indent = "", comments = false, parent_tag = string.none) =
  case el.kind
  of ElKind.el:
    # if newlines: html.add "\n"
    let (nel, nattrs) = el.normalize

    if nel.tag == "tr" and parent_tag.is_some and parent_tag.get notin ["tbody", "thead"]:
      # Checking correct HTML structure for tables, it's important for dynamic updates with diff
      throw "tr must have tbody or thead parent, not: " & parent_tag.get

    html.add indent & "<" & nel.tag
    for k, (v, attr_kind) in nattrs:
      if attr_kind == bool_prop:
        case v
        of "true":  html.add " " & k
        of "false": discard
        else:       throw "unknown input value"
      else:
        html.add " " & k & "=\"" & v.escape_html & "\""

    # if nel.tag.is_self_closing_tag:
    #   result.add "/>"
    # else:
    html.add ">"
    unless nel.children.is_empty:
      if nel.children.len == 1 and nel.children[0].kind in [ElKind.text, ElKind.html]:
        # Single text or html content
        nel.children[0].to_html(html, comments = comments)
      else:
        html.add "\n"
        let newlines = "c" in nel.children[0]
        for child in nel.children:
          if newlines: html.add "\n"
          child.to_html(html, indent = indent & "  ", comments = comments, parent_tag = el.tag.some)
          html.add "\n"
        if newlines: html.add "\n"
        html.add indent
    html.add "</" & nel.tag & ">"
    # if newlines: html.add "\n"
  of ElKind.text:
    html.add el.text_data.escape_html(quotes = false)
  of ElKind.html:
    html.add el.html_data
  of ElKind.list:
    for i, item in el.children:
      item.to_html(html, indent = indent, comments = comments)
      if i < el.children.high: html.add "\n"

proc to_html*(el: El, indent = "", comments = false): SafeHtml =
  el.to_html(result, indent = indent, comments = comments)

proc to_html*(els: openarray[El], indent = "", comments = false): string =
  els.map((el) => el.to_html(indent = indent, comments = comments)).join("\n")

# attrs --------------------------------------------------------------------------------------------
proc attr*[T](self: El, k: string, v: T) =
  self.attrs[k] = v.to_s

proc value*[T](self: El, v: T) =
  self.attr("value", v)

proc text*[T](self: El, text: T) =
  self.children.add text_el(text.to_s)

proc html*(self: El, html: SafeHtml) =
  self.children.add html_el(html)

proc style*(self: El, style: string | tuple) =
  when typeof(style) is tuple:
    var buff: string; var first = true
    for k, v in style.field_pairs:
      if first: first = false
      else:     buff.add " "
      buff.add k.replace("_", "-") & ": " & v.to_s & ";"
    self.attr("style", buff)
  else:
    self.attr("style", style)

proc class*(self: El, class: string) =
  let class = if "class" in self: self["class"] & " " & class else: class
  self.attr "class", class

template set_attrs*(self: El, attrs: tuple) =
  for k, v in attrs.field_pairs:
    when k == "class": self.class v
    elif k == "text":  self.text  v
    elif k == "html":  self.html  v
    elif k == "style": self.style v
    else:              self.attr(k, v)

proc add*(parent: El, child: El) =
  if child.kind == list: parent.children.add child.children
  else:                  parent.children.add child

proc add*(parent: El, list: seq[El]) =
  parent.children.add list

# template -----------------------------------------------------------------------------------------
template build_el*(expr: string, attrs: untyped, code: untyped): El =
  block:
    let it {.inject.} = El.init(expr) # El.init(fmt(html, '{', '}'))
    it.set_attrs(attrs)
    code
    it

template try_assign_untyped_to_variable*(body: untyped) =
  let tmp = body

template build_el*(expr: string, attrs_or_code: untyped): El =
  block:
    let it {.inject.} = El.init(expr)
    when compiles(try_assign_untyped_to_variable(attrs_or_code)): it.set_attrs(attrs_or_code)
    else:                                                         attrs_or_code
    it

template build_el*(html: string): El =
  El.init(html) # El.init(fmt(html, '{', '}'))

template els*(code): seq[El] =
  block:
    var it {.inject.} = seq[El].init
    code
    it

template list_el*(code): El =
  El(kind: ElKind.list, children: els(code))

template add_or_return_el*(e_arg: El): auto =
  let e = e_arg
  assert not e.is_nil
  when declared(it):
    when typeof(it) is El:      it.children.add e
    elif typeof(it) is seq[El]: it.add e
    else:                       e
  else:                         e

# template el*(html: string, attrs: tuple, code): auto =
#   add_or_return_el build_el(html, attrs, code)

template el*(html: string, attrs, code): auto =
  add_or_return_el build_el(html, attrs, code)

template el*(html: string, attrs_or_code): auto =
  add_or_return_el build_el(html, attrs_or_code)

template el*(html: string): auto =
  add_or_return_el build_el(html)

test "el, basics":
  check el("ul.todos", it.class("editing")).to_html == """<ul class="todos editing"></ul>"""
  check el("ul.todos", (class: "editing")).to_html  == """<ul class="todos editing"></ul>"""
  check el("ul.todos", (class: "a"), it.class("b")).to_html == """<ul class="todos a b"></ul>"""
  check el("", (style: (bg_color: "block"))).to_html == """<div style="bg-color: block;"></div>"""

  discard els(el("a", el("b"))) # should work

  let h =
    el".parent":
      el".counter":
        el("input type=text", (value: "some"))
        el("button", (text: "+"))
  let html = """
    <div class="parent">
      <div class="counter">
        <input type="text" value="some"></input>
        <button>+</button>
      </div>
    </div>""".dedent
  check h.to_html == html

# normalize ----------------------------------------------------------------------------------------
proc normalize*(el: El): (El, OrderedTable[string, ElAttrVal]) =
  assert el.kind == ElKind.el
  var el = el
  var attrs: Table[string, ElAttrVal]
  for k, v in el.attrs:
    if k != "c": attrs[k] = (v, string_attr)

  if el.tag == "input" and "value" in attrs: # input
    if "type" in el and el["type"] == "checkbox":
      # Normalising value for checkbox
      assert el.children.is_empty
      case attrs["value"][0]
      of "true":  attrs["checked"] = ("true", bool_prop)
      of "false": discard
      else:       throw "unknown input value"
      attrs.del "value"
    else:
      attrs["value"] = (attrs["value"][0], string_prop)
  elif el.tag == "textarea" and "value" in attrs: # textarea
    el = el.dcopy
    el.html attrs["value"][0].SafeHtml
    attrs.del "value"

  (el, attrs.sort)