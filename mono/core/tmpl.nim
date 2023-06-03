import std/macros
import base, ./component, ./mono_el

# component el -------------------------------------------------------------------------------------
# macro call_fn*(f, self, t: typed): typed =
#   var args = newSeq[NimNode]()
#   let ty = getTypeImpl(t)
#   args.add(self)
#   for child in ty:
#     let nparam = newNimNode(nnkExprEqExpr)
#     nparam.add child[0]
#     nparam.add newDotExpr(t, child[0])
#     args.add(nparam)
#   newCall(f, args)

macro call_set_attrs*(self: typed, targs: tuple) =
  var args = newSeq[NimNode]()
  let ty = getTypeImpl(targs)
  args.add(self)
  for child in ty:
    let nparam = newNimNode(nnkExprEqExpr)
    nparam.add child[0]
    nparam.add newDotExpr(targs, child[0])
    args.add(nparam)
  newCall(ident"set_attrs", args)

template build_el*[T](ComponentT: type[T], attrs: tuple, code): El =
  let component = when compiles(ComponentT.init): ComponentT.init else: ComponentT()
  call_set_attrs(component, attrs)
  let content = els(code)
  render(component, content)

template build_el*[T](ComponentT: type[T], attrs: tuple): El =
  let component = when compiles(ComponentT.init): ComponentT.init else: ComponentT()
  call_set_attrs(component, attrs)
  render(component)

template el*[T](ComponentT: type[T], attrs: tuple, code): auto =
  add_or_return_el build_el(ComponentT, attrs, code)

template el*[T](ComponentT: type[T], attrs: tuple): auto =
  add_or_return_el build_el(ComponentT, attrs)

# stateful component el ----------------------------------------------------------------------------
template build_el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple, code): El =
  let component = parent.get_child_component(ChildT, id)
  call_set_attrs(component, attrs)
  let content = els(code)
  render(component, content)

template build_el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple): El =
  let component = parent.get_child_component(ChildT, id)
  call_set_attrs(component, attrs)
  render(component)

template el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple, code): auto =
  add_or_return_el build_el(parent, ChildT, id, attrs, code)

template el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple): auto =
  add_or_return_el build_el(parent, ChildT, id, attrs)

# proc component el --------------------------------------------------------------------------------
macro call_fn_with_content_r*(f: proc, tuple_args: tuple, content_arg: typed, r: typed): typed =
  var args = newSeq[NimNode]()
  let ty = getTypeImpl(tuple_args)
  for child in ty:
    let nparam = newNimNode(nnkExprEqExpr)
    nparam.add child[0]
    nparam.add newDotExpr(tuple_args, child[0])
    args.add(nparam)

  let nparam = newNimNode(nnkExprEqExpr)
  nparam.add ident"content"
  nparam.add content_arg
  args.add(nparam)

  let call_expr = newCall(f, args)
  quote do:
    `r` = `call_expr`

macro call_fn_r*(f: proc, tuple_args: tuple, r: typed): typed =
  var args = newSeq[NimNode]()
  let ty = getTypeImpl(tuple_args)
  for child in ty:
    let nparam = newNimNode(nnkExprEqExpr)
    nparam.add child[0]
    nparam.add newDotExpr(tuple_args, child[0])
    args.add(nparam)
  let call_expr = newCall(f, args)
  quote do:
    `r` = `call_expr`

template build_el*(fn: proc, attrs: tuple, code): El =
  let content = els(code)
  var el: El
  call_fn_with_content_r(fn, attrs, content, el)
  el

template build_el*(fn: proc, attrs: tuple): El =
  var el: El
  call_fn_r(fn, attrs, el)
  el

template el*(fn: proc, attrs: tuple, code): auto =
  add_or_return_el build_el(fn, attrs, code)

template el*(fn: proc, attrs: tuple): auto =
  add_or_return_el build_el(fn, attrs)

# alter --------------------------------------------------------------------------------------------
template alter_el*(el_expression, code): auto =
  let el_to_alter = block:
    var it {.inject.} = seq[El].init
    el_expression
    assert it.len == 1
    it[0]
  block:
    var it {.inject.} = el_to_alter
    code
  add_or_return_el el_to_alter
