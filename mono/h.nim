import std/macros
import base, ext/url, ./component

# h ------------------------------------------------------------------------------------------------
# converter to_html_elements*(el: HtmlElement): seq[HtmlElement] =
#   # Needed to return single or multiple html elements from render
#   @[el]

template `+`*(node: HtmlElement): void =
  it.children.add node

template `+`*(node: seq[HtmlElement]): void =
  it.children.add node

template `+`*(node: HtmlElement, code): void =
  let n = node
  it.children.add n
  block:
    let it {.inject.} = n
    code

template `+`*(component: Component): void =
  let c = component
  it.children.add c.render()

template h*(html: string): HtmlElement =
  HtmlElement.init(tag = fmt(html, '{', '}'))

template h*(html: string, code): HtmlElement =
  let node = HtmlElement.init(tag = fmt(html, '{', '}'))
  block:
    let it {.inject.} = node
    code
  node

proc attr*[T](self: HtmlElement, k: string, v: T): HtmlElement =
  self.attrs[k] = v.to_json
  self

proc value*[T](self: HtmlElement, v: T): HtmlElement =
  self.attr("value", v)

proc text*[T](self: HtmlElement, text: T): HtmlElement =
  self.attr("text", text)

proc class*(self: HtmlElement, class: string): HtmlElement =
  self.attr("class", class)

proc extras_getset*(self: HtmlElement): HtmlElementExtras =
  if self.extras.is_none: self.extras = HtmlElementExtras().some
  self.extras.get

template bind_to*(element: HtmlElement, variable): HtmlElement =
  let el = element
  discard el.value variable
  el.extras_getset.set_value = (proc (v: string): void {.closure.} =
    variable = typeof(variable).parse v
    el.attrs["value"] = variable.to_json # updating value on the element, to avoid it being detected by diff
  ).some
  el

proc on_click*(self: HtmlElement, fn: proc(e: ClickEvent): void): HtmlElement =
  self.extras_getset.on_click = fn.some
  self

proc on_click*(self: HtmlElement, fn: proc: void): HtmlElement =
  self.extras_getset.on_click = (proc(e: ClickEvent): void = fn()).some
  self

proc on_dblclick*(self: HtmlElement, fn: proc(e: ClickEvent): void): HtmlElement =
  self.extras_getset.on_dblclick = fn.some
  self

proc on_dblclick*(self: HtmlElement, fn: proc: void): HtmlElement =
  self.extras_getset.on_dblclick = (proc(e: ClickEvent): void = fn()).some
  self

proc on_keydown*(self: HtmlElement, fn: proc(e: KeydownEvent): void): HtmlElement =
  self.extras_getset.on_keydown = fn.some
  self

proc on_change*(self: HtmlElement, fn: proc(e: ChangeEvent): void): HtmlElement =
  self.extras_getset.on_change = fn.some
  self

proc on_blur*(self: HtmlElement, fn: proc(e: BlurEvent): void): HtmlElement =
  self.extras_getset.on_blur = fn.some
  self

proc on_blur*(self: HtmlElement, fn: proc: void): HtmlElement =
  self.extras_getset.on_blur = (proc(e: BlurEvent): void = fn()).some
  self

test "h":
  let html = h"ul.c1":
    for text in @["Buy milk"]:
      + h"li.c2"
        .attr("class", "c3")
        .text("t1")
        .on_click(proc (e: auto): void = discard)

  check html.to_json ==
    """{"class":"c1","tag":"ul","children":[{"class":"c2 c3","text":"t1","tag":"li"}]}""".parse_json

# document_h ---------------------------------------------------------------------------------------
# template document_h*(title: string, location: Url, code): HtmlElement =
#   h"document":
#     discard it.attr("title", title)
#     discard it.attr("location", location)
#     code

# test "document_h":
#   let html = document_h("t1", Url.init("/a")):
#     + h"div"
#   check html.to_json == """{"title":"t1","location":"/a","tag":"document","children":[{"tag":"div"}]}""".parse_json


# stateful h ---------------------------------------------------------------------------------------
template h*[T](
  self: Component, ChildT: type[T], id: string, set_attrs: (proc(component: T): void)
): seq[HtmlElement] =
  let child = self.get_child_component(ChildT, id, set_attrs)
  let html = child.render
  when html is seq: html else: @[html]

template h*[T](self: Component, ChildT: type[T], id: string): seq[HtmlElement] =
  self.h(ChildT, id, proc(c: T): void = (discard))

macro call_fn*(f, self, t: typed): typed =
  var args = newSeq[NimNode]()
  let ty = getTypeImpl(t)
  # assert(ty.typeKind == ntyTuple)
  args.add(self)
  for child in ty:
    # expectKind(child, nnkIdentDefs)
    # args.add(newDotExpr(t, child[0]))
    let nparam = newNimNode(nnkExprEqExpr)
    nparam.add child[0]
    nparam.add newDotExpr(t, child[0])
    args.add(nparam)
  result = newCall(f, args)

template h*[T](self: Component, ChildT: type[T], id: string, attrs: tuple): seq[HtmlElement] =
  self.h(ChildT, id, proc(c: T): void = set_attrs.call_fn(c, attrs))
  # let child = self.get_child_component(ChildT, id, proc(c: T): void =
  #   set_attrs.call_fn(c, attrs)
  # )
  # let html = child.render
  # when html is seq: html else: @[html]

# escape_html --------------------------------------------------------------------------------------
const ESCAPE_HTML_MAP = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  """: "&quot;",
  """: "&#39;"
}.to_table

proc escape_html*(html: string): string =
  html.replace(re"""([&<>'"])""", (c) => ESCAPE_HTML_MAP[c])

test "escape_html":
  assert escape_html("<div>") == """&lt;div&gt;"""

# to_html ------------------------------------------------------------------------------------------
proc escape_html_text(s: string): string = s.escape_html
proc escape_html_attr(k: string, v: JsonNode): string =
  k.escape_html & "=" & (if v.kind == JString: "\"" & v.get_str.escape_html & "\"" else: v.to_s(false))

proc to_html*(el: JsonNode, indent = ""): string =
  assert el.kind == JObject, "to_html element data should be JObject"
  var tag = "div"
  var attr_tokens: seq[string]
  for k, v in el.sort.fields:
    if k == "tag":        tag = v.get_str
    elif k == "children": discard
    elif k == "text":     discard
    else:                 attr_tokens.add escape_html_attr(k, v)
  result.add indent & "<" & tag
  if not attr_tokens.is_empty:
    result.add " " & attr_tokens.join(" ")
  if "text" in el:
    assert "children" notin el, "to_html doesn't support both text and children"
    let text = el["text"].get_str
    result.add ">" & text.escape_html_text & "</" & tag & ">"
  elif "children" in el:
    let children = el["children"]
    assert children.kind == JArray, "to_html element children should be JArray"
    result.add ">\n"
    for v in children:
      result.add v.to_html(indent & "  ") & "\n"
    result.add indent & "</" & tag & ">"
  else:
    result.add "/>"

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

proc to_html*(events: seq[OutEvent]): string =
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
  update.set.get.to_html