import basem, jsonm, httpm, web/serverm
from fs import nil

export jsonm, httpm, serverm

proc cfun_send*[D, R](fn: string, data: D, _: type[R]): R =
  http_post[R](fmt"http://localhost:5000/rpc/{fn}?format=json", data.to_json, timeout_sec = 2)

proc cfun_impl*[R](fn: string, tr: type[R]): R =
  cfun_send(fn, (), tr)

proc cfun_impl*[A, R](fn: string, a: A, tr: type[R]): R =
  cfun_send(fn, (a: a), tr)

proc cfun_impl*[A, B, R](fn: string, a: A, b: B, tr: type[R]): R =
  cfun_send(fn, (a: a, b: b), tr)

proc cfun_impl*[A, B, C, R](fn: string, a: A, b: B, c: C, tr: type[R]): R =
  cfun_send(fn, (a: a, b: b, c: c), tr)

proc get_name_args_and_return_type(impl: NimNode): (string, seq[NimNode], NimNode) =
  # p impl.tree_repr()
  # Getting argument names and return type for fn
  var fsignature: seq[NimNode]
  let formal_params = impl.find_child(it.kind == nnkFormalParams)
  if formal_params.len == 1:
    for formal_param in formal_params:
      # For function without arguments
      if formal_param.kind == nnkSym:
        fsignature.add(formal_param)
  else:
    for formal_param in formal_params:
      # For function with arguments
      if formal_param.kind != nnkIdentDefs:
        continue
      for param in formal_param:
        if param.kind != nnkEmpty:
          # fsignature.add(param.symbol.`$`)
          fsignature.add(param)
  (impl[0].symbol.`$`, fsignature[0..^2], fsignature[^1])

macro cfun*(fn: typed) =
  # Generating code
  let (fname, args, rtype) = get_name_args_and_return_type(get_impl(fn.symbol))
  if args.len == 0:
    quote do:
      return cfun_impl(`fname`, type `rtype`)
  elif args.len == 1:
    let a = args[0]
    quote do:
      return cfun_impl(`fname`, `a`, type `rtype`)
  elif args.len == 2:
    let (a, b) = (args[0], args[1])
    quote do:
      return cfun_impl(`fname`, `a`, `b`, type `rtype`)
  elif args.len == 3:
    let (a, b, c) = (args[0], args[1], args[2])
    quote do:
      return cfun_impl(`fname`, `a`, `b`, `c`, type `rtype`)
  else:
    quote do:
      not supported


var rserver* = Server.init(port = 5000)

type CFun* = tuple[name: string, args: seq[(string, string)], rtype: string]
var sfuns_definitions*: seq[CFun]

macro sfun*(fn: typed): void =
  # fn.tree_repr()

  # Generating client functions
  let sfun_definition: CFun = block:
    let (fname, args, rtype) = get_name_args_and_return_type(fn)
    let args_s = args.map(proc (name: auto): auto = ($name, "todo"))
    ($fname, args_s, $rtype)

  if fn.kind == nnkProcDef:
    # Used as pragma `{.sfun.}`
    let thefn = fn[0]
    let fname = thefn.str_val
    quote do:
      sfuns_definitions.add `sfun_definition`
      sfun_impl(`fname`, `thefn`)
      `fn`
  else:
    # Used as macro `sfun fn`
    let fname = fn.str_val
    quote do:
      sfuns_definitions.add `sfun_definition`
      sfun_impl(`fname`, `fn`)

proc sfun_impl*[R](fn: string, op: proc: R): void =
  rserver.post_data(fmt"/rpc/{fn}", proc (req: Request): auto =
    op()
  )

proc sfun_impl*[A, R](fn: string, op: proc(a: A): R): void =
  rserver.post_data(fmt"/rpc/{fn}", proc (req: Request): auto =
    let a = req.data["a"].to(A)
    op(a)
  )

proc sfun_impl*[A, B, R](fn: string, op: proc(a: A, b: B): R): void =
  rserver.post_data(fmt"/rpc/{fn}", proc (req: Request): auto =
    let (a, b) = (req.data["a"].to(A), req.data["b"].to(B))
    op(a, b)
  )

proc sfun_impl*[A, B, C, R](fn: string, op: proc(a: A, b: B, c: C): R): void =
  rserver.post_data(fmt"/rpc/{fn}", proc (req: Request): auto =
    let (a, b, c) = (req.data["a"].to(A), req.data["b"].to(B), req.data["c"].to(C))
    op(a, b, c)
  )

proc generate_cfuns*(fname: string): void =
  let funcs_s = sfuns_definitions.map(proc (sfun: auto): auto =
    let args_s = sfun.args.map((arg) => fmt"{arg[0]}: {arg[1]}").join(", ")
    fmt"""proc {sfun.name}*({args_s}): {sfun.rtype} = cfun {sfun.name}"""
  )
  let code = "import rpc/rpcm\n\n" & funcs_s.join("\n\n")
  fs.write(fname, code)