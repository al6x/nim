import options, hashes, sets, strformat, strutils, re, sequtils, sugar
import ./supportm, ./nexportm

export nexportm

# generate_nimports --------------------------------------------------------------------------------
proc generate_nimports*(
  fname:    string,
  as_async: Option[bool],
  prepend:  Option[string]
): void =
  # Generates nimported functions
  # By default sync/async would be same as in nexported function, it could be changed with `as_async`
  var statements: seq[string]

  # Addin imports and node
  let default_prepend = fmt"""
    # Auto-generated code, do not edit
    import nodem, options, tables""".dedent
  statements.add prepend.get(default_prepend)

  # Adding custom nodes declarations
  let node_types = nexported_functions.values.map((nfn) => nfn.fsign[1][0][1]).to_hash_set
  for ntype in node_types:
    if ntype != "Node":
      let nname = ntype.replace(re"Node$", "")
      if ntype != fmt"{nname}Node": throw fmt"not supported node type name, should be like '{nname}Node'"

      statements.add fmt"""
        type {ntype}* = ref object of Node
        proc {nname.to_lower}_node*(id: string): {ntype} = {ntype}(id: id)""".dedent

  # Addin nexported functions
  for nfn in nexported_functions.values:
    let fsign = nfn.fsign
    let is_async = as_async.get fsign[3]

    # Declaring function
    let narg_s = fmt"node: {fsign[1][0][1]}"
    let rargs_s = fsign[1][1..^1].map((arg) => fmt"{arg[0]}: {arg[1]}").join(", ")
    let args_s = narg_s & (if rargs_s == "": "" else: ", " & rargs_s)
    let rtype = if is_async: fmt"Future[{fsign[2]}]"
    else:                    fsign[2]
    let nimport_pragma = "{.nimport.}"
    statements.add fmt"proc {fsign[0]}*({args_s}): {rtype} {nimport_pragma} = discard"

  let code = statements.join("\n\n")

  # Avoiding writing file if it's the same
  let existing_code = try: read_file(fname) except: ""
  if existing_code != code: write_file(fname, code)

proc generate_nimports*(fname: string): void =
  generate_nimports(fname, as_async = bool.none, prepend = string.none)