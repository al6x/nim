import json, tables, strutils, strformat, sequtils, sugar, macros, options, sets, os
import ./nodem/supportm, ./nodem/addressm, ./nodem/anetm

export json, addressm, parent_dir, on_receive

# fn_signature -------------------------------------------------------------------------------------
type FnSignature = (NimNode, seq[(NimNode, NimNode, NimNode)], NimNode, bool)
#                  (fname,       [aname,   atype,   adefault], rtype,   async)
# `NimNodes` have are of `nnk_sym` except of `arg_default` which is `nnk_empty` or custom literal type.

type FnSignatureS = (string, seq[(string, string, Option[string])], string, bool)
proc to_s(fsign: FnSignature): FnSignatureS =
  let args = fsign[1].map((arg) => (
    arg[0].str_val, arg[1].str_val, if arg[2].kind == nnk_empty: string.none else: arg[2].str_val.some)
  )
  (fsign[0].str_val, args, fsign[2].str_val, fsign[3])

proc fn_signature(fn_raw: NimNode): FnSignature =
  let invalid_usage = "invalid usage, if you think it's a valid case please update the code to suppor it"
  let fn_impl = case fn_raw.kind
  of nnk_sym:      fn_raw.get_impl
  of nnk_proc_def: fn_raw
  else:            throw fmt"{invalid_usage}, {fn_raw.kind}"
  # echo fn_impl.tree_repr()

  let fname = fn_impl.name
  assert fname.kind == nnk_sym, invalid_usage

  let rnode = fn_impl.params()[0] # return type is the first one
  let (rtype, is_async) = case rnode.kind
  of nnk_sym: # plain fn
    (rnode, false)
  of nnk_bracket_expr: # async fn
    assert rnode.len == 2, invalid_usage
    assert rnode[0].str_val == "Future", invalid_usage
    (rnode[1], true)
  else:
    throw invalid_usage
  # assert rtype.kind in [nnk_sym, nnk_bracket_expr], invalid_usage

  var args: seq[(NimNode, NimNode, NimNode)]
  for i in 1 ..< fn_impl.params.len:  # first is return type
    let idents = fn_impl.params[i]
    let (arg_type, arg_default) = (idents[^2], idents[^1])
    assert arg_type.kind == nnk_sym, invalid_usage
    for j in 0 ..< idents.len-2:  # last are arg type and default value
      let arg_name = idents[j]
      assert arg_name.kind == nnk_sym, invalid_usage
      args.add((arg_name, arg_type, arg_default))
  (fname, args, rtype, is_async)

test "fn_signature":
  macro get_fn_signature(fn: typed): string =
    let signature = fn.fn_signature.repr
    quote do:
      `signature`

  proc fn_0_args: float = 0.0
  assert get_fn_signature(fn_0_args) == "(fn_0_args, [], float)"

  proc fn_1_args(c: string): float = 0.0
  assert get_fn_signature(fn_1_args) == "(fn_1_args, [(c, string, )], float)"

  proc fn_1_args_with_default(c: string = "some"): float = 0.0
  assert get_fn_signature(fn_1_args_with_default) == """(fn_1_args_with_default, [(c, string, "some")], float)"""

  type Cache = (int, int)
  proc fn_custom_arg_type(c: Cache): float = 0.0
  assert get_fn_signature(fn_custom_arg_type) == "(fn_custom_arg_type, [(c, Cache, )], float)"

  proc fn_2_args(c: string, d: int): float = 0.0
  assert get_fn_signature(fn_2_args) == "(fn_2_args, [(c, string, ), (d, int, )], float)"

  proc fn_2_comma_args(c, d: string): float = 0.0
  assert get_fn_signature(fn_2_comma_args) == "(fn_2_comma_args, [(c, string, ), (d, string, )], float)"


# nexport ------------------------------------------------------------------------------------------
macro nexport*(fn: typed) =
  # Export function as remotelly called function, so it would be possible to call it from other nodes

  let fsign = fn_signature(fn)
  let (fsymb, fsigns, is_async) = (fsign[0], fsign.to_s, fsign[3])

  for arg in fsign[1]:
    if arg[2].kind != nnk_empty:
      throw "defaults not supported yet, please consider updating the code to support it"

  if is_async:
    case fn.kind
    of nnk_proc_def: # Used as pragma `{.sfun.}`
      quote do:
        nexport_function(`fsigns`, `fsymb`)
        `fn`
    of nnk_sym: # Used as macro `sfun fn`
      quote do:
        nexport_function(`fsigns`, `fsymb`)
    else:
      throw fmt"invalid usage, if you think it's a valid case please update the code to suppor it, {fn.kind}"
  else:
    case fn.kind
    of nnk_proc_def: # Used as pragma `{.sfun.}`
      quote do:
        nexport_function(`fsigns`, `fsymb`)
        `fn`
    of nnk_sym: # Used as macro `sfun fn`
      quote do:
        nexport_function(`fsigns`, `fsymb`)
    else:
      throw fmt"invalid usage, if you think it's a valid case please update the code to suppor it, {fn.kind}"

# macro anexport*(fn: typed) =
#   # Export function as remotelly called function, so it would be possible to call it from other nodes

#   let fsign = fn_signature(fn)
#   let (fsymb, fsigns) = (fsign[0], fsign.to_s)

#   for arg in fsign[1]:
#     if arg[2].kind != nnk_empty:
#       throw "defaults not supported yet, please consider updating the code to support it"

#   case fn.kind
#   of nnk_proc_def: # Used as pragma `{.sfun.}`
#     quote do:
#       anexport_function(`fsigns`, `fsymb`)
#       `fn`
#   of nnk_sym: # Used as macro `sfun fn`
#     quote do:
#       discard
#       # anexport_function(`fsigns`, `fsymb`)
#   else:
#     throw fmt"invalid usage, if you think it's a valid case please update the code to suppor it, {fn.kind}"


# nexport_function ---------------------------------------------------------------------------------
type NFHandler = proc (args: JsonNode): Future[JsonNode] # can throw errors

type NexportedFunction = ref object
  fsign:   FnSignatureS
  handler: NFHandler
var nexported_functions: Table[string, NexportedFunction]

proc full_name(s: FnSignatureS): string =
  # Full name with argument types and return values, needed to support multiple dispatch
  template normalize (s: string): string = s.replace("_", "").replace(" ", "").to_lower
  let args_s = s[1].map((arg) => fmt"{arg[0].normalize}: {arg[1].normalize}").join(", ")
  fmt"{s[0].normalize}({args_s}): {s[2].normalize}"

proc nexport_function*[R](fsign: FnSignatureS, fn: proc: R): void =
  proc nfhandler(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 0
    return %fn()
  nexported_functions[fsign.full_name] = NexportedFunction(fsign: fsign, handler: nfhandler)

proc nexport_function*[R](fsign: FnSignatureS, fn: proc: Future[R]): void =
  proc nfhandler(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 0
    return %(await fn())
  nexported_functions[fsign.full_name] = NexportedFunction(fsign: fsign, handler: nfhandler)

proc nexport_function*[A, R](fsign: FnSignatureS, fn: proc(a: A): R): void =
  proc nfhandler(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 1
    return %fn(args[0].to(A))
  nexported_functions[fsign.full_name] = NexportedFunction(fsign: fsign, handler: nfhandler)

proc nexport_function*[A, R](fsign: FnSignatureS, fn: proc(a: A): Future[R]): void =
  proc nfhandler(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 1
    return %(await fn(args[0].to(A)))
  nexported_functions[fsign.full_name] = NexportedFunction(fsign: fsign, handler: nfhandler)

proc nexport_function*[A, B, R](fsign: FnSignatureS, fn: proc(a: A, b: B): R): void =
  proc nfhandler(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 2
    return %fn(args[0].to(A), args[1].to(B))
  nexported_functions[fsign.full_name] = NexportedFunction(fsign: fsign, handler: nfhandler)

proc nexport_function*[A, B, R](fsign: FnSignatureS, fn: proc(a: A, b: B): Future[R]): void =
  proc nfhandler(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 2
    return %(await fn(args[0].to(A), args[1].to(B)))
  nexported_functions[fsign.full_name] = NexportedFunction(fsign: fsign, handler: nfhandler)

proc nexport_function*[A, B, C, R](fsign: FnSignatureS, fn: proc(a: A, b: B, c: C): R): void =
  proc nfhandler(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 3
    return %fn(args[0].to(A), args[1].to(B), args[2].to(C))
  nexported_functions[fsign.full_name] = NexportedFunction(fsign: fsign, handler: nfhandler)

proc nexport_function*[A, B, C, R](fsign: FnSignatureS, fn: proc(a: A, b: B, c: C): Future[R]): void =
  proc nfhandler(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 3
    return %(await fn(args[0].to(A), args[1].to(B), args[2].to(C)))
  nexported_functions[fsign.full_name] = NexportedFunction(fsign: fsign, handler: nfhandler)


# nexport_handler ----------------------------------------------------------------------------------
proc nexport_handler*(req: string): Future[Option[string]] {.async.} =
  # Use it to start as RPC server
  try:
    let data = req.parse_json
    let (fname, args) = (data["fname"].get_str, data["args"])
    if fname notin nexported_functions: throw fmt"no server function '{fname}'"
    let nfn = nexported_functions[fname]
    let res = await nfn.handler(args)
    return (is_error: false, result: res).`%`.`$`.some
  except Exception as e:
    return (is_error: true, message: e.msg).`%`.`$`.some


# nimport ------------------------------------------------------------------------------------------
macro nimport*(address: string, fn: typed): typed =
  # Import remote function from remote address to be able to call it

  let fsign  = fn_signature(fn)
  let fsigns = fsign.to_s
  let (full_name, args, rtype, is_async) = (fsigns.full_name, fsign[1], fsign[2], fsign[3])

  # Generating code
  if is_async: throw "use `nimport_async` for async"
  case args.len:
  of 0:
    quote do:
      return wait_for call_nimported_function(`address`, `full_name`, typeof `rtype`)
  of 1:
    let a = args[0][0]
    quote do:
      return wait_for call_nimported_function(`address`, `full_name`, `a`, typeof `rtype`)
  of 2:
    let (a, b) = (args[0][0], args[1][0])
    quote do:
      return wait_for call_nimported_function(`address`, `full_name`, `a`, `b`, typeof `rtype`)
  of 3:
    let (a, b, c) = (args[0][0], args[1][0], args[2][0])
    quote do:
      return wait_for call_nimported_function(`address`, `full_name`, `a`, `b`, `c`, typeof `rtype`)
  else:
    quote do:
      raise new_exception(Exception, "not supported, please update the code to suppor it")

macro nimport_async*(address: string, fn: typed): Future[typed] =
  # Import remote function from remote address to be able to call it

  let fsign  = fn_signature(fn)
  let fsigns = fsign.to_s
  let (full_name, args, rtype, is_async) = (fsigns.full_name, fsign[1], fsign[2], fsign[3])

  # Generating code
  if not is_async: throw "use `nimport` for sync"
  case args.len:
  of 0:
    quote do:
      call_nimported_function(`address`, `full_name`, typeof `rtype`)
  of 1:
    let a = args[0][0]
    quote do:
      call_nimported_function(`address`, `full_name`, `a`, typeof `rtype`)
  of 2:
    let (a, b) = (args[0][0], args[1][0])
    quote do:
      call_nimported_function(`address`, `full_name`, `a`, `b`, typeof `rtype`)
  of 3:
    let (a, b, c) = (args[0][0], args[1][0], args[2][0])
    quote do:
      call_nimported_function(`address`, `full_name`, `a`, `b`, `c`, typeof `rtype`)
  else:
    quote do:
      raise new_exception(Exception, "not supported, please update the code to suppor it")


# call_nimported_function -----------------------------------------------------------------------------
proc call_nimported_function(address: string, fname: string, args: JsonNode): Future[JsonNode] {.async.} =
  assert args.kind == JArray
  let res = await Address(address).call((fname: fname, args: args).`%`.`$`)
  let data = res.parse_json
  if data["is_error"].get_bool: throw data["message"].get_str
  return data["result"]

proc call_nimported_function*[R](
  address: string, fname: string, rtype: type[R]
): Future[R] {.async.} =
  let args = newJArray()
  return (await call_nimported_function(address, fname, args)).to(R)

proc call_nimported_function*[A, R](
  address: string, fname: string, a: A, tr: type[R]
): Future[R] {.async.} =
  let args = newJArray(); args.add %a
  return (await call_nimported_function(address, fname, args)).to(R)

proc call_nimported_function*[A, B, R](
  address: string, fname: string, a: A, b: B, tr: type[R]
): Future[R] {.async.} =
  let args = newJArray(); args.add %a; args.add %b;
  return (await call_nimported_function(address, fname, args)).to(R)

proc call_nimported_function*[A, B, C, R](
  address: string, fname: string, a: A, b: B, c: C, tr: type[R]
): Future[R] {.async.} =
  let args = newJArray(); args.add %a; args.add %b; args.add %c
  return (await call_nimported_function(address, fname, args)).to(R)


# generate_nimport ---------------------------------------------------------------------------------
const default_prepend = """
# Auto-generated code, do not edit
import nodem, asyncdispatch
export nodem, asyncdispatch"""

proc generate_nimport*(address: Address, folder: string, prepend = default_prepend): void =
  var statements: seq[string]
  statements.add $prepend

  # var declared_addresses: HashSet[string]
  for nfn in nexported_functions.values:
    let fsign = nfn.fsign

    # # Declaring address
    # if address notin declared_addresses:
    #   statements.add fmt"""let {address}* = Node("{address}")"""
    #   declared_addresses.incl address

    # Declaring function
    if fsign[3]: # async
      let args_s = fsign[1].map((arg) => fmt"{arg[0]}: {arg[1]}").join(", ")
      statements.add(
        fmt"""proc {fsign[0]}*({args_s}): Future[{fsign[2]}]""" & " {.async.} =\n" &
        fmt"""  return await nimport_async("{address}", {fsign[0]})"""
      )
    else: # sync
      let args_s = fsign[1].map((arg) => fmt"{arg[0]}: {arg[1]}").join(", ")
      statements.add(
        fmt"""proc {fsign[0]}*({args_s}): {fsign[2]} =""" & "\n" &
        fmt"""  nimport("{address}", {fsign[0]})"""
      )

  let code = statements.join("\n\n")

  # Avoiding writing file if it's the same
  let path = folder / fmt"{address}i.nim"
  let existing_code =
    try: read_file(path)
    except: ""

  if existing_code != code:
    write_file(path, code)


# run ----------------------------------------------------------------------------------------------
template run*(address: Address, generate = false) =
  if generate:
    const script_dir = instantiation_info(full_paths = true).filename.parent_dir
    generate_nimport(address, script_dir)
  wait_for address.on_receive(nexport_handler)
  run_forever()

template run*(address: Address, self: proc: Future[void], generate = false) =
  if generate:
    const script_dir = instantiation_info(full_paths = true).filename.parent_dir
    generate_nimport(address, script_dir)
  # first starting the loop, because self could initiate have backward `self -> remote -> self` call
  # so the self-node-loop needs to be available before self.
  async_check address.on_receive(nexport_handler)
  # await sleep_sync 1
  async_check self()
  run_forever()



# # nexport_handler ----------------------------------------------------------------------------------
# proc nexport_handler_http*(req: string): Future[Option[string]] {.async.} =
#   # Use it to start as RPC server
#   try:
#     let data = req.parse_json
#     let (fname, args) = (data["fname"].get_str, data["args"])
#     if fname notin nexported_functions: throw fmt"no server function '{fname}'"
#     let nfn = nexported_functions[fname]
#     let res = nfn.handler(args)
#     discard %((a: 1))
#     return (is_error: false, result: res).`%`.`$`.some
#   except Exception as e:
#     return (is_error: true, message: e.msg).`%`.`$`.some
