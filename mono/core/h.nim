import std/macros, ext/url
import base, ./component, ./html_element

# attrs --------------------------------------------------------------------------------------------
proc attr*[T](self: HtmlElement, k: string, v: T) =
  self.attrs[k] = v.to_json

proc c*(self: HtmlElement, c: string) =
  self.attr("c", c)

proc value*[T](self: HtmlElement, v: T) =
  self.attr("value", v)

proc text*[T](self: HtmlElement, text: T) =
  self.attr("text", text)

proc style*(self: HtmlElement, style: string) =
  self.attr("style", style)

proc class*(self: HtmlElement, class: string) =
  self.attr("class", class)

proc location*[T](self: HtmlElement, location: T) =
  self.attr("href", location.to_s)

proc window_title*(self: HtmlElement, title: string) =
  self.attr("window_title", title)

proc window_location*[T](self: HtmlElement, location: T) =
  self.attr("window_location", location.to_s)

# proc window_location*[T](els: openarray[HtmlElement], location: T) =
#   assert els.len > 0, "window_location requires at least one element"
#   els[0].window_location(location)

# url ----------------------------------------------------------------------------------------------
proc to_url*(path: openarray[string], params: openarray[(string, string)] = @[]): Url =
  Url.init(path.to_seq, params.to_table)

# events -------------------------------------------------------------------------------------------
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

# build_el -----------------------------------------------------------------------------------------
template build_el*(html: string, blk): HtmlElement =
  block:
    let it {.inject.} = HtmlElement.init(tag = fmt(html, '{', '}'))
    blk
    it

template build_el*(html: string): HtmlElement =
  build_el(html):
    discard

template add_el*(html: string, code) =
  let parent = it
  block:
    let it {.inject.} = build_el(html)
    code
    parent.children.add it

template add_el*(html: string) =
  add_el(html):
    discard

# build_component ----------------------------------------------------------------------------------
macro call_fn*(f, self, t: typed): typed =
  var args = newSeq[NimNode]()
  let ty = getTypeImpl(t)
  args.add(self)
  for child in ty:
    let nparam = newNimNode(nnkExprEqExpr)
    nparam.add child[0]
    nparam.add newDotExpr(t, child[0])
    args.add(nparam)
  newCall(f, args)

template build_component*[T](ComponentT: type[T], attrs: tuple, blk): HtmlElement =
  let component = when compiles(ComponentT.init): ComponentT.init else: ComponentT()
  when compiles(call_fn(set_attrs, component, attrs)):
    call_fn(set_attrs, component, attrs)
  else:
    set_from_tuple(component[], attrs)
  block:
    let it {.inject.} = component
    blk
  component.render

template build_component*[T](ComponentT: type[T], attrs: tuple): HtmlElement =
  build_component(ComponentT, attrs):
    discard

template add_component*[T](ComponentT: type[T], attrs: tuple, blk) =
  it.children.add build_component(ComponentT, attrs, blk)

template add_component*[T](ComponentT: type[T], attrs: tuple) =
  add_component(ComponentT, attrs, blk):
    discard


# build_proc_component -----------------------------------------------------------------------------
macro call_fn_r*(f, t, r: typed): typed =
  var args = newSeq[NimNode]()
  let ty = getTypeImpl(t)
  for child in ty:
    let nparam = newNimNode(nnkExprEqExpr)
    nparam.add child[0]
    nparam.add newDotExpr(t, child[0])
    args.add(nparam)
  let call_expr = newCall(f, args)
  quote do:
    `r` = `call_expr`

template build_proc_component*(fn: proc, attrs: tuple, blk): HtmlElement =
  var el: HtmlElement
  call_fn_r(fn, attrs, el)
  block:
    let it {.inject.} = el
    blk
    it

template build_proc_component*(fn: proc, attrs: tuple): HtmlElement =
  build_proc_component(fn, attrs):
    discard

template add_proc_component*(fn: proc, attrs: tuple, blk) =
  it.children.add build_proc_component(fn, attrs, blk)

template add_proc_component*(fn: proc, attrs: tuple) =
  add_proc_component(fn, attrs):
    discard


# build_stateful_component -------------------------------------------------------------------------
template build_stateful_component*[T](
  self: Component, ChildT: type[T], id: string, attrs: tuple, blk
): HtmlElement =
  let component = self.get_child_component(ChildT, id)
  when compiles(call_fn(set_attrs, component, attrs)):
    call_fn(set_attrs, component, attrs)
  else:
    set_from_tuple(component[], attrs)
  block:
    let it {.inject.} = component
    blk
  component.render

template build_stateful_component*[T](
  self: Component, ChildT: type[T], id: string, attrs: tuple
): HtmlElement =
  build_stateful_component(self, ChildT, id, attrs):
    discard

template add_stateful_component*[T](
  self: Component, ChildT: type[T], id: string, attrs: tuple, blk
) =
  it.children.add build_stateful_component(self, ChildT, id, attrs, blk)

template add_stateful_component*[T](
  self: Component, ChildT: type[T], id: string, attrs: tuple
) =
  add_stateful_component(self, ChildT, id, attrs):
    discard


# build_h ------------------------------------------------------------------------------------------
template build_h*(html: string, blk): HtmlElement =
  build_el(html, blk)
template build_h*(html: string): HtmlElement =
  build_el(html)

template build_h*[T](ComponentT: type[T], attrs: tuple, blk): HtmlElement =
  build_component(ComponentT, attrs, blk)
template build_h*[T](ComponentT: type[T], attrs: tuple): HtmlElement =
  build_component(ComponentT, attrs)

template build_h*(fn: proc, attrs: tuple, blk): HtmlElement =
  build_proc_component(fn, attrs, blk)
template build_h*(fn: proc, attrs: tuple): HtmlElement =
  build_proc_component(fn, attrs)

template build_h*[T](
  self: Component, ChildT: type[T], id: string, attrs: tuple, blk
): HtmlElement =
  build_stateful_component(self, ChildT, id, attrs, blk)
template build_h*[T](
  self: Component, ChildT: type[T], id: string, attrs: tuple
): HtmlElement =
  build_stateful_component(self, ChildT, id, attrs)


template h*(html: string, code) =
  add_el(html, code)
template h*(html: string) =
  add_el(html)

template h*[T](ComponentT: type[T], attrs: tuple, blk) =
  add_component(ComponentT, attrs, blk)
template h*[T](ComponentT: type[T], attrs: tuple) =
  add_component(ComponentT, attrs)

template h*(fn: proc, attrs: tuple, blk) =
  add_proc_component(fn, attrs, blk)
template h*(fn: proc, attrs: tuple) =
  add_proc_component(fn, attrs)

template h*[T](
  self: Component, ChildT: type[T], id: string, attrs: tuple, blk
) =
  add_stateful_component(self, ChildT, id, attrs, blk)
template h*[T](
  self: Component, ChildT: type[T], id: string, attrs: tuple
) =
  add_stateful_component(self, ChildT, id, attrs)