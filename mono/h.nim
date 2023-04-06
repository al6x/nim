import base, ./app, std/macros

# h ------------------------------------------------------------------------------------------------
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
  HtmlElement(tag: fmt(html, '{', '}'), attrs: new_JObject())

template h*(html: string, code): HtmlElement =
  let node = HtmlElement(tag: fmt(html, '{', '}'), attrs: new_JObject())
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
  when `variable` is bool:
    discard el.value `variable`
    el.extras_getset.bind_bool_value = (proc (v: bool): void =
      `variable` = v
    ).some
  elif `variable` is string:
    echo "use single bind_value and cast inside"
    discard el.value `variable`
    el.extras_getset.bind_string_value = (proc (v: string): void =
      `variable` = v
    ).some
  elif `variable` is Option[bool]:
    discard el.value `variable`
    el.extras_getset.bind_bool_value = (proc (v: bool): void =
      `variable` = v.some
    ).some
  elif `variable` is Option[string]:
    discard el.value `variable`
    el.extras_getset.bind_string_value = (proc (v: string): void =
      `variable` = v.some
    ).some
  else:
    throw "invalid binding variable type"
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


# stateful h ---------------------------------------------------------------------------------------
template h*[T](
  self: Component, ChildT: type[T], id: string, set_attrs: (proc(component: T): void)
): seq[HtmlElement] =
  let child = self.get_child_component(ChildT, id, set_attrs)
  let html = child.render
  when html is seq: html else: @[html]

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
  let child = self.get_child_component(ChildT, id, proc(c: T): void =
    set_attrs.call_fn(c, attrs)
  )
  let html = child.render
  when html is seq: html else: @[html]