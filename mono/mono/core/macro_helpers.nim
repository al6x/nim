import std/macros

template is_object_fields_subset_equal_to_tuple*[T](obj: T, attrs: tuple): bool =
  var r = true
  block is_object_fields_subset_equal_to_tuple_block:
    for tk, tv in field_pairs(attrs):
      for ok, ov in field_pairs(obj[]):
        when ok == tk:
          if ov != tv:
            r = false
            break is_object_fields_subset_equal_to_tuple_block
  r

macro call_set_attrs*(self: typed, tuple_args: tuple) =
  # Rewrites `tuple_args` tuple as function arguments and calls `self.set_attrs(args)`
  var args = newSeq[NimNode]()
  let ty = getTypeImpl(tuple_args)
  args.add(self)
  for child in ty:
    let nparam = newNimNode(nnkExprEqExpr)
    nparam.add child[0]
    nparam.add newDotExpr(tuple_args, child[0])
    args.add(nparam)
  newCall(ident"set_attrs", args)

template set_attrs_from_tuple*[T](obj: T, attrs: tuple) =
  for tk, tv in field_pairs(attrs):
    block field_found:
      for ok, ov in field_pairs(obj[]):
        when ok == tk:
          ov = tv
          break field_found

template component_set_attrs*[T](component: T, attrs: untyped) =
  let attrsv = attrs
  # if not is_object_fields_subset_equal_to_tuple(component, attrsv):
  # Performance optimisation, setting attributes only if they changed, as `c.set_attrs` may contain
  # expensive calculations. Actually, it can't be done, as component may have large objects as attrs.

  when compiles(call_set_attrs(component, attrsv)): call_set_attrs(component, attrsv)
  else:                                             set_attrs_from_tuple(component, attrsv)

macro call_fn_with_content_r*(f: proc, tuple_args: tuple, content_arg: typed, r: typed): typed =
  # Executes`r = f(tuple_args rewritten as args, content: content_arg)`
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
  # Executes `r = f(tuple_args rewritten as args)`
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