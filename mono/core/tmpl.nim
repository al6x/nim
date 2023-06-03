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

template build_el*[T](ComponentT: type[T], attrs: tuple, blk): El =
  let content = block:
    var it {.inject.} = seq[El].init
    blk
    it
  let component = when compiles(ComponentT.init): ComponentT.init else: ComponentT()
  call_set_attrs(component, attrs)
  render(component, content)

template build_el*[T](ComponentT: type[T], attrs: tuple): El =
  let component = when compiles(ComponentT.init): ComponentT.init else: ComponentT()
  call_set_attrs(component, attrs)
  render(component)

template el*[T](ComponentT: type[T], attrs: tuple, blk): auto =
  add_or_return_el build_el(ComponentT, attrs, blk)

template el*[T](ComponentT: type[T], attrs: tuple): auto =
  add_or_return_el build_el(ComponentT, attrs)

# stateful component el ----------------------------------------------------------------------------
template build_el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple, blk): El =
  let content = block:
    var it {.inject.} = seq[El].init
    blk
    it

  let component = parent.get_child_component(ChildT, id)
  call_set_attrs(component, attrs)
  render(component, content)

template build_el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple): El =
  let component = parent.get_child_component(ChildT, id)
  call_set_attrs(component, attrs)
  render(component)

template el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple, blk): auto =
  add_or_return_el build_el(parent, ChildT, id, attrs, blk)

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

# type ProcComponentDoesntAcceptContent* = object
template build_el*(fn: proc, attrs: tuple, blk): El =
  block:
    var it {.inject.} = seq[El].init
    blk
    var el: El
    call_fn_with_content_r(fn, attrs, it, el)
    el

template build_el*(fn: proc, attrs: tuple): El =
  var el: El
  call_fn_r(fn, attrs, el)
  el

template el*(fn: proc, attrs: tuple, blk): auto =
  add_or_return_el build_el(fn, attrs, blk)

template el*(fn: proc, attrs: tuple): auto =
  add_or_return_el build_el(fn, attrs)

# alter --------------------------------------------------------------------------------------------
template alter_el*(el_expression, blk): auto =
  let el_to_alter = block:
    var it {.inject.} = seq[El].init
    el_expression
    assert it.len == 1
    it[0]
  block:
    var it {.inject.} = el_to_alter
    blk
  add_or_return_el el_to_alter
