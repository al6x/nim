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

proc add*(parent: El, child: El | seq[El]) =
  parent.children.add child

template els*(code): seq[El] =
  el("", code).children

# html el ------------------------------------------------------------------------------------------
template add_or_return*(e: El): auto =
  when compiles(it.add(e)): it.add(e) else: e

template el*(html: string, code): auto =
  add_or_return:
    block:
      let it {.inject.} = El.init(tag = fmt(html, '{', '}'))
      code
      it

template el*(html: string): auto =
  el(html):
    discard


# component el -------------------------------------------------------------------------------------
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

template el*[T](ComponentT: type[T], attrs: tuple, blk): auto =
  let component = when compiles(ComponentT.init): ComponentT.init else: ComponentT()
  when compiles(call_fn(set_attrs, component, attrs)):
    call_fn(set_attrs, component, attrs)
  else:
    set_from_tuple(component[], attrs)
  block:
    let it {.inject.} = component
    blk
  add_or_return component.render

template el*[T](ComponentT: type[T], attrs: tuple): auto =
  el(ComponentT, attrs):
    discard

# proc component el --------------------------------------------------------------------------------
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

template el*(fn: proc, attrs: tuple, blk): auto =
  var el: El
  call_fn_r(fn, attrs, el)
  block:
    let it {.inject.} = el
    blk
  add_or_return el

template el*(fn: proc, attrs: tuple): auto =
  el(fn, attrs):
    discard

# steteful component el ----------------------------------------------------------------------------
template el*[T](self: Component, ChildT: type[T], id: string, attrs: tuple, blk): auto =
  let component = self.get_child_component(ChildT, id)
  when compiles(call_fn(set_attrs, component, attrs)):
    call_fn(set_attrs, component, attrs)
  else:
    set_from_tuple(component[], attrs)
  block:
    let it {.inject.} = component
    blk
  add_or_return component.render

template el*[T](self: Component, ChildT: type[T], id: string, attrs: tuple): auto =
  el(self, ChildT, id, attrs):
    discard