import base

type
  SafeHtml* = string

  ElAttrs* = JsonNode
  ElExtras* = ref object of RootObj
  ElKind* = enum el, text, html, list
  El* = ref object
    children*: seq[El]
    case kind*: ElKind
    of el:
      tag*:   string
      attrs*: ElAttrs
    of text:
      text_data*: string
    of html:
      html_data*: SafeHtml
    of list:
      discard
    extras*: Option[ElExtras] # Integration with other frameworks

proc parse_tag*(s: string): tuple[tag: string, attrs: ElAttrs]
proc escape_html*(html: string, quotes = true): SafeHtml
proc escape_js*(js: string): SafeHtml

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

proc scopy*(self: El): El =
  # el.extras won't be copied
  case self.kind
  of el:   El(kind: el, tag: self.tag, attrs: self.attrs.scopy, children: self.children, extras: self.extras)
  of text: El(kind: text, text_data: self.text_data, extras: self.extras)
  of html: El(kind: html, html_data: self.html_data, extras: self.extras)
  of list: El(kind: list, children: self.children, extras: self.extras)

proc flatten*(list: seq[El], result: var seq[El]) =
  for el in list:
    if el.kind == ElKind.list: flatten(el.children, result)
    else:                      result.add el

proc flatten*(list: seq[El]): seq[El] =
  list.flatten(result)

# helpers ------------------------------------------------------------------------------------------
proc attr*[T](self: El, k: string, v: T) =
  self.attrs[k] = v.to_json

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
  var class = class.replace(".", " ")
  class = if "class" in self.attrs: self.attrs["class"].get_str & " " & class else: class
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
  El.init(html)

template els*(code): seq[El] =
  block:
    var it {.inject.} = seq[El].init
    code
    it

template list_el*(code): El =
  El(kind: ElKind.list, children: els(code))

template list_el*(): El =
  El(kind: ElKind.list)

template add_or_return_el*(e_arg: El): auto =
  let e = e_arg
  assert not e.is_nil
  when declared(it):
    when typeof(it) is El:      it.children.add e
    elif typeof(it) is seq[El]: it.add e
    else:                       e
  else:                         e

template el*(html: string, attrs, code): auto =
  add_or_return_el build_el(html, attrs, code)

template el*(html: string, attrs_or_code): auto =
  add_or_return_el build_el(html, attrs_or_code)

template el*(html: string): auto =
  add_or_return_el build_el(html)

# to_json, to_html ---------------------------------------------------------------------------------
proc to_json_hook*(el: El): JsonNode =
  case el.kind
  of ElKind.el:
    if el.children.is_empty: %{ kind: el.kind, tag: el.tag, attrs: el.attrs }
    else:                    %{ kind: el.kind, tag: el.tag, attrs: el.attrs, children: el.children.flatten }
  of ElKind.text:            %{ kind: el.kind, text: el.text_data }
  of ElKind.html:            %{ kind: el.kind, html: el.html_data }
  of ElKind.list:            throw "json for el.list is not implemented"

proc validate*(el: El, parent = El.none) =
  case el.kind
  of ElKind.el:
    if el.tag == "tr" and parent.is_some and parent.get.tag notin ["tbody", "thead"]:
      # Correct table HTML important for dynamic updates, for diff to work correctly
      throw "tr must have tbody or thead parent, not: " & parent.get.tag
    for child in el.children: child.validate(el.some)
  of ElKind.text: discard
  of ElKind.html: discard
  of ElKind.list:
    for child in el.children: child.validate(el.some)

proc normalize*(el: El): tuple[el: El, bool_attrs: seq[string]] =
  assert el.kind == ElKind.el
  # value attribute should be rendered differently for different elements, as `value` attribute for `input`, but
  # as `inner_html` for `textarea`.
  # var el = el.dcopy; var bool_attrs: seq[string]
  if el.tag == "input" and "type" in el.attrs and el.attrs["type"].get_str == "checkbox": # checkbox
    var el = el.scopy
    if "value" in el.attrs:
      assert el.attrs["value"].kind in [JBool, JNull], "value for checkbox should be bool"
      assert el.children.is_empty
      el.attrs["checked"] = el.attrs["value"]
      el.attrs.delete "value"
    (el, @["checked"])
  elif el.tag == "textarea": # textarea
    var el = el.scopy
    if "value" in el.attrs:
      assert el.children.is_empty, "textarea should use value to set its content"
      let v = el.attrs["value"]
      el.html if v.kind in [JString, JNull]: v.get_str("") else: v.to_s
      el.attrs.delete "value"
    (el, @["checked"])
  else:
    (el, seq[string].init)

proc encode_attr_value*(v: JsonNode): string =
  case v.kind
  of   [JString, JNull]: v.get_str("").escape_html
  else:                  v.to_s.escape_html

proc to_html*(el: El, html: var SafeHtml, indent = "", comments = false) =
  case el.kind
  of ElKind.el:
    let (el, bool_attrs) = el.normalize
    html.add indent & "<" & el.tag
    for k, v in el.attrs.sort:
      if k in bool_attrs:
        assert v.kind in [JBool, JNull], "bool_attr should be bool"
        if v.get_bool(false): html.add " " & k
      else:
        # html.add " " & k & "=\"" & v.escape_html & "\""
        html.add " " & k & "=\"" & v.encode_attr_value & "\""
    html.add ">"
    let nchildren = el.children.flatten
    unless nchildren.is_empty:
      if nchildren.len == 1 and nchildren[0].kind in [ElKind.text, ElKind.html]:
        nchildren[0].to_html(html, comments = comments) # Single text or html content
      else:
        html.add "\n"
        let newlines = "c" in nchildren[0].attrs
        for child in nchildren:
          if newlines: html.add "\n"
          child.to_html(html, indent = indent & "  ", comments = comments)
          html.add "\n"
        if newlines: html.add "\n"
        html.add indent
    html.add "</" & el.tag & ">"
  of ElKind.text:
    html.add el.text_data.escape_html(quotes = false)
  of ElKind.html:
    html.add el.html_data
  of ElKind.list:
    for i, item in el.children.flatten:
      item.to_html(html, indent = indent, comments = comments)
      if i < el.children.high: html.add "\n"

proc to_html*(el: El, indent = "", comments = false): SafeHtml =
  el.to_html(result, indent = indent, comments = comments)

proc to_html*(els: openarray[El], indent = "", comments = false): string =
  els.map((el) => el.to_html(indent = indent, comments = comments)).join("\n")

# parse_tag ----------------------------------------------------------------------------------------
proc parse_tag*(s: string): tuple[tag: string, attrs: ElAttrs] =
  const special = {'#', '.', '$'}
  const delimiters = special + {' '}

  # Parses `"span#id.c1.c2 type=checkbox required"`
  var tag = "div"; var attrs = newJObject()

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
    of '$': attrs["c"] = consume_token(i).to_json  # component
    of '#': attrs["id"] = consume_token(i).to_json # id
    of '.': classes.add consume_token(i)   # class
    else:   throw "internal error"
    skip_space()

  if not classes.is_empty: attrs["class"] = classes.join(" ").to_json

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
      attrs[tokens[0]] = if tokens.len > 1: tokens[1].to_json else: true.to_json

  (tag, attrs)

# exape_html, exape_js -----------------------------------------------------------------------------
proc escape_html*(html: string, quotes = true): SafeHtml =
  let escape_map {.global.} = { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }.to_table
  let escape_re {.global.} = re"""([&<>'"])"""
  let partial_map {.global.} = { "&": "&amp;", "<": "&lt;", ">": "&gt;" }.to_table
  let partial_re {.global.} = re"""([&<>])"""

  if quotes: html.replace(escape_re, (c) => escape_map[c])
  else:      html.replace(partial_re, (c) => partial_map[c])

proc escape_js*(js: string): SafeHtml =
  js.to_json.to_s.replace(re"""^"|"$""", "")

proc svg_to_url_data*(svg: string): SafeHtml =
  ("data:image/svg+xml,").escape_html(quotes = false)
    .replace("\"", "'") # not necessary, but makes it more nice and shorter

# test ---------------------------------------------------------------------------------------------
test "el, basics":
  check:
    el("ul.todos", it.class("editing")).to_html == """<ul class="todos editing"></ul>"""
    el("ul.todos", (class: "editing")).to_html  == """<ul class="todos editing"></ul>"""
    el("ul.todos", (class: "a"), it.class("b")).to_html == """<ul class="todos a b"></ul>"""
    el("", (style: (bg_color: "block"))).to_html == """<div style="bg-color: block;"></div>"""

  let tmpl =
    el".parent":
      el".counter":
        el("input type=text", (value: "some"))
        el("button", (text: "+"))

  check tmpl.to_html == """
    <div class="parent">
      <div class="counter">
        <input type="text" value="some"></input>
        <button>+</button>
      </div>
    </div>""".dedent

test "els":
  discard els(el("a", el("b"))) # should work

test "parse_tag":
  check:
    parse_tag("span#id.c-1.c2 .c3  .c-4 type=checkbox required") == (
      "span", %{ id: "id", class: "c-1 c2 c3 c-4", type: "checkbox", required: true })

    parse_tag("span")     == ("span", %{})
    parse_tag("#id")      == ("div",  %{ id: "id" })
    parse_tag(".c-1")     == ("div",  %{ class: "c-1" })
    parse_tag("div  a=b") == ("div",  %{ a: "b" })
    parse_tag(" .a  a=b") == ("div",  %{ class: "a", a: "b" })
    parse_tag(" .a")      == ("div",  %{ class: "a" })

    parse_tag("$controls .a")    == ("div",      %{ c: "controls", class: "a" })
    parse_tag("$controls.a")     == ("div",      %{ c: "controls", class: "a" })
    parse_tag("button$button.a") == ("button",   %{ c: "button", class: "a" })
    parse_tag("block-ft .a")     == ("block-ft", %{ class: "a" })

test "escape_html":
  check escape_html("""<div attr="val">""").to_s == "&lt;div attr=&quot;val&quot;&gt;"

test "escape_js":
  check escape_js("""); alert("hi there""") == """); alert(\"hi there"""