import basem, ./nexportm

export nexportm

# generate_nimports --------------------------------------------------------------------------------
let default_prepend = fmt"""
  # Auto-generated code, do not edit
  import nodem, options, tables""".dedent

proc generate_nimports*(
  fname:    string,
  prepend = default_prepend
): void =
  # Generates nimported functions
  var statements: seq[string]

  # Addin imports and node
  statements.add prepend

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
    if fsign[3]: throw fmt"async not supported, {fsign}"

    # Declaring function
    let narg_s = fmt"node: {fsign[1][0][1]}"
    let rargs_s = fsign[1][1..^1].map((arg) => fmt"{arg[0]}: {arg[1]}").join(", ")
    let args_s = narg_s & (if rargs_s == "": "" else: ", " & rargs_s)
    let rtype = fsign[2]
    let nimport_pragma = "{.nimport.}"
    statements.add fmt"proc {fsign[0]}*({args_s}): {rtype} {nimport_pragma} = discard"

  let code = statements.join("\n\n")

  # Avoiding writing file if it's the same
  let existing_code = try: read_file(fname) except: ""
  if existing_code != code: write_file(fname, code)