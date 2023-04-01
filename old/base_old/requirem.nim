import std/[strutils, macros]

macro require*(modules: varargs[untyped]) =
  var moduless: seq[string]
  for m in modules:
    let ms = $m
    if "[" in ms: # namespace/[module1, module2]
      let parts = ms.split("/")
      echo parts
      if parts.len > 2: raise Exception.new_exception("invalid module name " & ms)
      let nspace = parts[0]
      let names = parts[1].replace("[").replace("]").split(",")
      for name in names: moduless.add nspace.replace(" ") & "/" & name.replace(" ")
    else:
      moduless.add ms

  result = nnk_stmt_list.new_tree()
  for m in moduless:
    let mname = new_ident_node(($m).split("/")[^1] & "m")
    result.add quote do:
      import `m` as `mname`