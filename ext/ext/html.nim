import base

# exape_html, exape_js -----------------------------------------------------------------------------
type SafeHtml* = string
# type SafeHtml* = distinct string # not working, Nim crashes https://github.com/nim-lang/Nim/issues/21800

const ESCAPE_HTML_MAP = { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }.to_table

proc escape_html*(html: string): SafeHtml =
  html.replace(re"""([&<>'"])""", (c) => ESCAPE_HTML_MAP[c])

test "escape_html":
  check escape_html("""<div attr="val">""").to_s == "&lt;div attr=&quot;val&quot;&gt;"

proc escape_js*(js: string): SafeHtml =
  js.to_json.to_s.replace(re"""^"|"$""", "")

test "escape_js":
  assert escape_js("""); alert("hi there""") == """); alert(\"hi there"""

# parse_tag ----------------------------------------------------------------------------------------
const special    = {'#', '.', '$'}
const delimiters = special + {' '}
proc parse_tag*(s: string): tuple[tag: string, attrs: Table[string, string]] =
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

# el -----------------------------------------------------------------------------------------------
type
  ElKind* = enum el, text, html, list
  El* = ref object
    children*: seq[El]
    case kind*: ElKind
    of el:
      tag*:      string
      attrs*:    Table[string, string]
    of text:
      text_data*: string
    of html:
      html_data*: SafeHtml
    of list:
      discard

proc init*(_: type[El], tag = "", attrs: openarray[(string, string)] = seq[(string, string)].init): El =
  var (parsed_tag, parsed_attrs) = parse_tag(tag)
  for (k, v) in attrs:
    if k in parsed_attrs:
      case k
      of "class": parsed_attrs["class"] = v & " " & parsed_attrs["class"]
      else:       throw fmt"can't redefine attribute '{k}' for '{tag}'"
    else:
      parsed_attrs[k] = v
  El(kind: ElKind.el, tag: parsed_tag, attrs: parsed_attrs)

proc html_el*(html: SafeHtml): El =
  El(kind: ElKind.html, html_data: html)

proc text_el*(text: string): El =
  El(kind: ElKind.text, text_data: text)

proc is_self_closing_tag(tag: string): bool =
  tag in ["img"]

proc to_html*(el: El, indent = "", comments = false): SafeHtml =
  case el.kind
  of ElKind.el:
    result.add indent & "<" & el.tag
    for k, v in el.attrs:
      result.add " " & k & "=\"" & v.escape_html & "\""
    if el.tag.is_self_closing_tag:
      result.add "/>"
    else:
      result.add ">"
      unless el.children.is_empty:
        # Single text or html content
        if el.children.len == 1 and el.children[0].kind in [ElKind.text, ElKind.html]:
          result.add el.children[0].to_html(comments = comments)
        else:
          result.add "\n"
          for child in el.children:
            result.add child.to_html(indent = indent & "  ", comments = comments) & "\n"
          result.add indent
      result.add "</" & el.tag & ">"
  of ElKind.text:
    result.add el.text_data.escape_html
  of ElKind.html:
    result.add el.html_data
  of ElKind.list:
    for i, item in el.children:
      result.add item.to_html(indent = indent, comments = comments)
      if i < el.children.high: result.add "\n"

proc to_html*(els: openarray[El], indent = "", comments = false): string =
  els.map((el) => el.to_html(indent = indent, comments = comments)).join("\n")

# attrs --------------------------------------------------------------------------------------------
proc attr*[T](self: El, k: string | int | bool, v: T) =
  self.attrs[k] = v.to_s

proc value*[T](self: El, v: T) =
  self.attr("value", v)

proc text*[T](self: El, text: T) =
  self.children.add text_el(text.to_s)

proc html*(self: El, html: SafeHtml) =
  self.children.add html_el(html)

proc style*(self: El, style: string) =
  self.attr("style", style)

proc class*(self: El, class: string) =
  let class = if "class" in self.attrs: self.attrs["class"] & " " & class else: class
  self.attr "class", class

# template -----------------------------------------------------------------------------------------
proc add*(parent: El, child: El | seq[El]) =
  parent.children.add child

template els*(code): El =
  block:
    var it {.inject.} = El(kind: ElKind.list)
    code
    it

template add_or_return*(e_arg: El): auto =
  let e = e_arg
  assert not e.is_nil
  when compiles(it.add(e)):         it.add(e)
  else:                             e

template el*(html: string, code): auto =
  let el = block:
    let it {.inject.} = El.init(fmt(html, '{', '}'))
    code
    it
  add_or_return el

template el*(html: string): auto =
  el(html, attrs):
    discard