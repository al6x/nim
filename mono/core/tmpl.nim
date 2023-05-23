import std/macros, ext/url
import base, ./component, ./el

# helpers ------------------------------------------------------------------------------------------
proc add*(parent: El, child: El | seq[El]) =
  parent.children.add child

template els*(code): seq[El] =
  block:
    let it {.inject.} = "`it` is not available in the 'els' block"
    var it_content {.inject.}: seq[El]
    code
    it_content

# html el ------------------------------------------------------------------------------------------
template add_or_return*(e: El): auto =
  assert not e.is_nil
  # Order is important, first `it` should be checked, see "nesting, from error" test case
  when compiles(it.add(e)):         it.add(e)
  elif compiles(it_content.add(e)): it_content.add(e)
  else:                             e

template el*(html: string, code): auto =
  let el = block:
    let it {.inject.} = El.init(tag = fmt(html, '{', '}'))
    let it_content {.inject.} = "`it_content` is not available in the 'el' html block"
    code
    it
  add_or_return el

template el*(html: string): auto =
  el(html):
    discard

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
  let cname = ast_to_str(ComponentT).replace(re"_\d+", "") # Nim sometimes adds tmp numbers to types

  call_set_attrs(component, attrs)
  # when compiles(call_fn(set_attrs, component, attrs)):
  #   call_fn(set_attrs, component, attrs)
  # else:
  #   set_from_tuple(component[], attrs)

  let content = block:
    let it {.inject.} = component
    var it_content {.inject.} = seq[El].init
    blk
    it_content

  let el =
    when compiles(render(component, content)):
      render(component, content)
    else:
      # assert content.is_empty, "component " & cname & " doesn't have content attribute in render"
      render(component)
  el.attr("c", cname)

  add_or_return el

template el*[T](ComponentT: type[T], attrs: tuple): auto =
  el(ComponentT, attrs):
    discard

# stateful component el ----------------------------------------------------------------------------
template el*[T](parent: Component, ChildT: type[T], id: string, attrs: tuple, blk): auto =
  let component = parent.get_child_component(ChildT, id)
  let cname = ast_to_str(ChildT).replace(re"_\d+", "") # Nim sometimes adds tmp numbers to types

  call_set_attrs(component, attrs)
  # when compiles(call_fn(set_attrs, component, attrs)):
  #   call_fn(set_attrs, component, attrs)
  # else:
  #   set_from_tuple(component[], attrs)

  let content = block:
    let it {.inject.} = component
    var it_content {.inject.} = seq[El].init
    blk
    it_content

  let el =
    when compiles(render(component, content)):
      render(component, content)
    else:
      # assert content.is_empty, "component " & cname & " doesn't have content attribute in render"
      render(component)
  el.attr("c", cname)

  add_or_return el

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
  let cname = ast_to_str(fn).replace(re"_\d+", "") # Nim sometimes adds tmp numbers to types

  var el: El
  when compiles(call_fn_r(fn, attrs, el)):
    call_fn_r(fn, attrs, el)
    block:
      var it {.inject.} = el
      let it_content {.inject.} = "`it_content` is not available in the 'el' proc block"
      blk
  else:
    block:
      let it {.inject.} = "`it` variable is not available in the 'proc component' with content"
      var it_content {.inject.} = seq[El].init
      blk
      call_fn_with_content_r(fn, attrs, it_content, el)
  el.attr("c", cname)

  add_or_return el

template el*(fn: proc, attrs: tuple): auto =
  el(fn, attrs):
    discard