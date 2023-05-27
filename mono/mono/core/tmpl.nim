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

template el*[T](ComponentT: type[T], attrs: tuple, blk): auto =
  let component = when compiles(ComponentT.init): ComponentT.init else: ComponentT()

  call_set_attrs(component, attrs)

  let content = block:
    var it {.inject.} = seq[El].init
    blk
    it

  let el =
    when compiles(render(component, content)):
      render(component, content)
    else:
      render(component)

  add_or_return_el el

template el*[T](ComponentT: type[T], attrs: tuple): auto =
  el(ComponentT, attrs):
    discard

# stateful component el ----------------------------------------------------------------------------
template el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple, blk): auto =
  let component = parent.get_child_component(ChildT, id)

  call_set_attrs(component, attrs)

  let content = block:
    var it {.inject.} = seq[El].init
    blk
    it

  let el =
    when compiles(render(component, content)):
      render(component, content)
    else:
      render(component)

  add_or_return_el el

template el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple): auto =
  el(parent, ChildT, id, attrs):
    discard

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

template el*(fn: proc, attrs: tuple, blk): auto =
  var el: El
  when compiles(call_fn_r(fn, attrs, el)):
    call_fn_r(fn, attrs, el)
    block:
      let it {.inject.} = "`it` is not available in the 'el' proc block"
      blk
  else:
    block:
      var it {.inject.} = seq[El].init
      blk
      call_fn_with_content_r(fn, attrs, it, el)

  add_or_return_el el

template el*(fn: proc, attrs: tuple): auto =
  el(fn, attrs):
    discard