import std/macros, ext/url
import base, ./component, ./html_element

# template build_html(blk): seq[HtmlElement] =
#   block:
#     let it {.inject.} = HtmlElement.init()
#     blk
#     it.children

template bh*(html: string): HtmlElement =
  HtmlElement.init(tag = fmt(html, '{', '}'))

template bh*(html: string, blk): HtmlElement =
  block:
    let it {.inject.} = HtmlElement.init(tag = fmt(html, '{', '}'))
    blk
    it

template h*(html: string) =
  it.children.add HtmlElement.init(tag = fmt(html, '{', '}'))

template h*(html: string, code) =
  let parent = it
  block:
    let it {.inject.} = HtmlElement.init(tag = fmt(html, '{', '}'))
    code
    parent.children.add it

proc attr*[T](self: HtmlElement, k: string, v: T) =
  self.attrs[k] = v.to_json

proc value*[T](self: HtmlElement, v: T) =
  self.attr("value", v)

proc text*[T](self: HtmlElement, text: T) =
  self.attr("text", text)

proc class*(self: HtmlElement, class: string) =
  self.attr("class", class)

proc location*[T](self: HtmlElement, location: T) =
  self.attr("href", location.to_s)

proc extras_getset*(self: HtmlElement): HtmlElementExtras =
  if self.extras.is_none: self.extras = HtmlElementExtras().some
  self.extras.get

proc init*(_: type[SetValueHandler], handler: (proc(v: string)), delay: bool): SetValueHandler =
  SetValueHandler(handler: handler, delay: delay)

template bind_to*(element: HtmlElement, variable, delay) =
  let el = element
  el.value variable

  el.extras_getset.set_value = SetValueHandler.init(
    (proc(v: string) {.closure.} =
      variable = typeof(variable).parse v
      el.attrs["value"] = variable.to_json # updating value on the element, to avoid it being detected by diff
    ),
    delay
  ).some

template bind_to*(element: HtmlElement, variable) =
  bind_to(element, variable, false)

proc on_click*(self: HtmlElement, fn: proc(e: ClickEvent)) =
  self.extras_getset.on_click = fn.some

proc on_click*(self: HtmlElement, fn: proc()) =
  self.extras_getset.on_click = (proc(e: ClickEvent) = fn()).some

proc on_dblclick*(self: HtmlElement, fn: proc(e: ClickEvent)) =
  self.extras_getset.on_dblclick = fn.some

proc on_dblclick*(self: HtmlElement, fn: proc()) =
  self.extras_getset.on_dblclick = (proc(e: ClickEvent) = fn()).some

proc on_keydown*(self: HtmlElement, fn: proc(e: KeydownEvent)) =
  self.extras_getset.on_keydown = fn.some

proc on_change*(self: HtmlElement, fn: proc(e: ChangeEvent)) =
  self.extras_getset.on_change = fn.some

proc on_blur*(self: HtmlElement, fn: proc(e: BlurEvent)) =
  self.extras_getset.on_blur = fn.some

proc on_blur*(self: HtmlElement, fn: proc()) =
  self.extras_getset.on_blur = (proc(e: BlurEvent) = fn()).some

test "h":
  let html = bh"ul.c1":
    for text in @["t1"]:
      h"li.c2":
        it.attr("class", "c3")
        it.text(text)
        it.on_click(proc (e: auto) = discard)

  check html.to_html == """
    <ul class="c1">
      <li class="c2 c3" on_click="true">t1</li>
    </ul>
  """.dedent.trim

# stateful h ---------------------------------------------------------------------------------------
template bh*[T](
  self: Component, ChildT: type[T], id: string, set_attrs: (proc(component: T))
): seq[HtmlElement] =
  let child = self.get_child_component(ChildT, id, set_attrs)
  let html = child.render
  when html is seq: html else: @[html]

template h*[T](
  self: Component, ChildT: type[T], id: string, set_attrs: (proc(component: T))
) =
  it.children.add bh(self, ChildT, id, set_attrs)

template h*[T](self: Component, ChildT: type[T], id: string) =
  h(self, ChildT, id, proc(c: T) = (discard))

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

template bh*[T](self: Component, ChildT: type[T], id: string, attrs: tuple): seq[HtmlElement] =
  h(self, ChildT, id, proc(c: T) = set_attrs.call_fn(c, attrs))

template h*[T](self: Component, ChildT: type[T], id: string, attrs: tuple) =
  it.children.add bh(self, ChildT, id, proc(c: T) = set_attrs.call_fn(c, attrs))

# to_url -------------------------------------------------------------------------------------------
proc to_url*(path: openarray[string], params: openarray[(string, string)] = @[]): Url =
  Url.init(path.to_seq, params.to_table)





# template h*[T](self: Component, ChildT: type[T], id: string): seq[HtmlElement] =
#   self.h(ChildT, id, proc(c: T) = (discard))


# proc window_title*(self: HtmlElement, title: string) =
#   self.attr("window_title", title)

# proc window_location*[T](self: HtmlElement, location: T) =
#   self.attr("window_location", location.to_s)

# proc window_location*[T](els: openarray[HtmlElement], location: T) =
#   assert els.len > 0, "window_location requires at least one element"
#   discard els[0].window_location(location)
#   els

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

# template content*(el: HtmlElement): HtmlElement =
#   el

# template content*(el: HtmlElement, code): HtmlElement =
#   let node = el
#   block:
#     let it {.inject.} = node
#     code
#   node

# test "h":
#   let html = h".blog".window_title("Blog").content:
#     + h".posts"

#   check html.to_html == """
#     <div class="blog" window_title="Blog">
#       <div class="posts"></div>
#     </div>
#   """.dedent.trim