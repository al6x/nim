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

template set_attrs_from_tuple*[T: Component](obj: T, attrs: tuple) =
  for tk, tv in field_pairs(attrs):
    block field_found:
      for ok, ov in field_pairs(obj[]):
        when ok == tk:
          ov = tv
          break field_found

template is_attrs_equal*[T: Component](obj: T, attrs: tuple): bool =
  var r = true
  block is_attrs_equal_block:
    for tk, tv in field_pairs(attrs):
      for ok, ov in field_pairs(obj[]):
        when ok == tk:
          if ov != tv:
            r = false
            break is_attrs_equal_block
  r

template component_set_attrs*[T: Component](component: T, attrs: untyped) =
  let attrsv = attrs
  if not is_attrs_equal(component, attrsv):
    # Performance optimisation, setting attributes only if they changed, as `c.set_attrs` may contain
    # expensive calculations.
    when compiles(call_set_attrs(component, attrsv)): call_set_attrs(component, attrsv)
    else:                                             set_attrs_from_tuple(component, attrsv)

template build_el*[T: Component](parent: Component, ChildT: type[T], id: string | int, attrs: tuple, code): El =
  let attrsv = attrs
  let component = parent.get_child_component(ChildT, id, proc(c: T) = c.component_set_attrs(attrs))
  let content = els(code)
  render(component, content)

template build_el*[T: Component](parent: Component, ChildT: type[T], id: string | int, attrs: tuple): El =
  let attrsv = attrs
  let component = parent.get_child_component(ChildT, id, proc(c: T) = c.component_set_attrs(attrs))
  render(component)

template build_el*[T: Component](parent: Component, ChildT: type[T], attrs: tuple, code): El =
  build_el(parent, ChildT, "", attrs, code)

template build_el*[T: Component](parent: Component, ChildT: type[T], attrs: tuple): El =
  build_el(parent, ChildT, "", attrs)


template el*[T: Component](parent: Component, ChildT: type[T], id: string | int, attrs: tuple, code): auto =
  add_or_return_el build_el(parent, ChildT, id, attrs, code)

template el*[T: Component](parent: Component, ChildT: type[T], id: string | int, attrs: tuple): auto =
  add_or_return_el build_el(parent, ChildT, id, attrs)

template el*[T: Component](parent: Component, ChildT: type[T], attrs: tuple, code): auto =
  add_or_return_el build_el(parent, ChildT, attrs, code)

template el*[T: Component](parent: Component, ChildT: type[T], attrs: tuple): auto =
  add_or_return_el build_el(parent, ChildT, attrs)

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
  let attrsv = attrs
  let content = els(code)
  var el: El
  call_fn_with_content_r(fn, attrsv, content, el)
  el

template build_el*(fn: proc, attrs: tuple): El =
  let attrsv = attrs
  var el: El
  call_fn_r(fn, attrsv, el)
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
