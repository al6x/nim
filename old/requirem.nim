import std/[strutils, macros]

macro require*(modules: varargs[untyped]) =
  var moduless: seq[string]

  # Normalizing module names, converting `namespace/[a, b]` into `namespace/a, namespace/b`
  for m in modules:
    let ms = m.repr().replace(" ").replace("\n")
    if "[" in ms:
      let parts = ms.split("/")
      if parts.len > 2: raise Exception.new_exception("invalid module name " & ms)
      let nspace = parts[0]
      let names = parts[1].replace("[").replace("]").split(",")
      for name in names:
        moduless.add nspace & "/" & name
    else:
      moduless.add ms

  # Importing modules with added postfix _m
  result = nnk_stmt_list.new_tree()
  for m in moduless:
    let ml = new_lit m
    let mname = new_ident_node(($m).split("/")[^1] & "_m")
    result.add quote do:
      import `ml` as `mname`