import std/macros, ext/url
import base, ./component, ./el

# attrs --------------------------------------------------------------------------------------------
proc attr*[T](self: El, k: string, v: T) =
  self.attrs[k] = v.to_json

proc c*(self: El, c: string) =
  self.attr("c", c)

proc value*[T](self: El, v: T) =
  self.attr("value", v)

proc text*[T](self: El, text: T) =
  self.attr("text", text)

proc style*(self: El, style: string) =
  self.attr("style", style)

proc class*(self: El, class: string) =
  self.attr("class", class)

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

# helpers ------------------------------------------------------------------------------------------
proc to_url*(path: openarray[string], params: openarray[(string, string)] = @[]): Url =
  Url.init(path.to_seq, params.to_table)

proc add*(parent: El, child: El | seq[El]): void =
  parent.children.add child

# build_el -----------------------------------------------------------------------------------------
template build_el*(html: string, blk): El =
  block:
    let it {.inject.} = El.init(tag = fmt(html, '{', '}'))
    blk
    it

template build_el*(html: string): El =
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

template build_component*[T](ComponentT: type[T], attrs: tuple, blk): El =
  let component = when compiles(ComponentT.init): ComponentT.init else: ComponentT()
  when compiles(call_fn(set_attrs, component, attrs)):
    call_fn(set_attrs, component, attrs)
  else:
    set_from_tuple(component[], attrs)
  block:
    let it {.inject.} = component
    blk
  component.render

template build_component*[T](ComponentT: type[T], attrs: tuple): El =
  build_component(ComponentT, attrs):
    discard

template add_component*[T](ComponentT: type[T], attrs: tuple, blk) =
  it.children.add build_component(ComponentT, attrs, blk)

template add_component*[T](ComponentT: type[T], attrs: tuple) =
  add_component(ComponentT, attrs):
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

template build_proc_component*(fn: proc, attrs: tuple, blk): El =
  var el: El
  call_fn_r(fn, attrs, el)
  block:
    let it {.inject.} = el
    blk
    it

template build_proc_component*(fn: proc, attrs: tuple): El =
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
): El =
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
): El =
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


# bh ------------------------------------------------------------------------------------------
template bh*(html: string, blk): El =
  build_el(html, blk)
template bh*(html: string): El =
  build_el(html)

template bh*[T: Component](ComponentT: type[T], attrs: tuple, blk): El =
  build_component(ComponentT, attrs, blk)
template bh*[T: Component](ComponentT: type[T], attrs: tuple): El =
  build_component(ComponentT, attrs)

template bh*(fn: proc, attrs: tuple, blk): El =
  build_proc_component(fn, attrs, blk)
template bh*(fn: proc, attrs: tuple): El =
  build_proc_component(fn, attrs)

template bh*[T](self: Component, ChildT: type[T], id: string, attrs: tuple, blk): El =
  build_stateful_component(self, ChildT, id, attrs, blk)
template bh*[T](self: Component, ChildT: type[T], id: string, attrs: tuple): El =
  build_stateful_component(self, ChildT, id, attrs)

template bhs*(blk): seq[El] =
  build_el("", blk).children


template h*(html: string, code) =
  add_el(html, code)
template h*(html: string) =
  add_el(html)

template h*[T: Component](ComponentT: type[T], attrs: tuple, blk) =
  add_component(ComponentT, attrs, blk)
template h*[T: Component](ComponentT: type[T], attrs: tuple) =
  add_component(ComponentT, attrs)

template h*(fn: proc, attrs: tuple, blk) =
  add_proc_component(fn, attrs, blk)
template h*(fn: proc, attrs: tuple) =
  add_proc_component(fn, attrs)

template h*[T](self: Component, ChildT: type[T], id: string, attrs: tuple, blk) =
  add_stateful_component(self, ChildT, id, attrs, blk)
template h*[T](self: Component, ChildT: type[T], id: string, attrs: tuple) =
  add_stateful_component(self, ChildT, id, attrs)