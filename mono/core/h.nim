import std/macros
import base, ext/url, ./component, ./html_element

template `+`*(node: HtmlElement) =
  it.children.add node

template `+`*(node: seq[HtmlElement]) =
  it.children.add node

template `+`*(node: HtmlElement, code) =
  let n = node
  it.children.add n
  block:
    let it {.inject.} = n
    code

template `+`*(component: Component) =
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

proc init*(_: type[SetValueHandler], handler: (proc(v: string)), delay: bool): SetValueHandler =
  SetValueHandler(handler: handler, delay: delay)

template bind_to*(element: HtmlElement, variable, delay): HtmlElement =
  let el = element
  discard el.value variable

  el.extras_getset.set_value = SetValueHandler.init(
    (proc(v: string) {.closure.} =
      variable = typeof(variable).parse v
      el.attrs["value"] = variable.to_json # updating value on the element, to avoid it being detected by diff
    ),
    delay
  ).some
  el

template bind_to*(element: HtmlElement, variable): HtmlElement =
  bind_to(element, variable, false)

proc on_click*(self: HtmlElement, fn: proc(e: ClickEvent)): HtmlElement =
  self.extras_getset.on_click = fn.some
  self

proc on_click*(self: HtmlElement, fn: proc()): HtmlElement =
  self.extras_getset.on_click = (proc(e: ClickEvent) = fn()).some
  self

proc on_dblclick*(self: HtmlElement, fn: proc(e: ClickEvent)): HtmlElement =
  self.extras_getset.on_dblclick = fn.some
  self

proc on_dblclick*(self: HtmlElement, fn: proc()): HtmlElement =
  self.extras_getset.on_dblclick = (proc(e: ClickEvent) = fn()).some
  self

proc on_keydown*(self: HtmlElement, fn: proc(e: KeydownEvent)): HtmlElement =
  self.extras_getset.on_keydown = fn.some
  self

proc on_change*(self: HtmlElement, fn: proc(e: ChangeEvent)): HtmlElement =
  self.extras_getset.on_change = fn.some
  self

proc on_blur*(self: HtmlElement, fn: proc(e: BlurEvent)): HtmlElement =
  self.extras_getset.on_blur = fn.some
  self

proc on_blur*(self: HtmlElement, fn: proc()): HtmlElement =
  self.extras_getset.on_blur = (proc(e: BlurEvent) = fn()).some
  self

test "h":
  let html = h"ul.c1":
    for text in @["Buy milk"]:
      + h"li.c2"
        .attr("class", "c3")
        .text("t1")
        .on_click(proc (e: auto) = discard)

  check html.to_json ==
    """{"class":"c1","tag":"ul","children":[{"class":"c2 c3","text":"t1","tag":"li","on_click":true}]}""".parse_json

# stateful h ---------------------------------------------------------------------------------------
template h*[T](
  self: Component, ChildT: type[T], id: string, set_attrs: (proc(component: T))
): seq[HtmlElement] =
  let child = self.get_child_component(ChildT, id, set_attrs)
  let html = child.render
  when html is seq: html else: @[html]

template h*[T](self: Component, ChildT: type[T], id: string): seq[HtmlElement] =
  self.h(ChildT, id, proc(c: T) = (discard))

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
  self.h(ChildT, id, proc(c: T) = set_attrs.call_fn(c, attrs))
  # let child = self.get_child_component(ChildT, id, proc(c: T) =
  #   set_attrs.call_fn(c, attrs)
  # )
  # let html = child.render
  # when html is seq: html else: @[html]



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

# h ------------------------------------------------------------------------------------------------
# converter to_html_elements*(el: HtmlElement): seq[HtmlElement] =
#   # Needed to return single or multiple html elements from render
#   @[el]
