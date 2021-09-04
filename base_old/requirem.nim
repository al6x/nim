import std/[strutils, macros]

macro require*(modules: varargs[untyped]) =
  result = nnk_stmt_list.newTree()
  for m in modules:
    let mname = new_ident_node(($m).split("/")[^1] & "m")
    result.add quote do:
      import `m` as `mname`