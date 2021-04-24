import json, tables, strutils, strformat, sequtils, sugar, macros, options, os
import ./nodem/supportm, ./nodem/addressm, ./nodem/netm

export json, addressm, parent_dir, receive_async

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
        nexport_async_function(`fsigns`, `fsymb`)
        `fn`
    of nnk_sym: # Used as macro `sfun fn`
      quote do:
        nexport_async_function(`fsigns`, `fsymb`)
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


# nexported_functions ------------------------------------------------------------------------------
type NFHandler = proc (args: JsonNode): Future[JsonNode] # can throw errors
type NFParser = proc (list: seq[string], map: Table[string, string]): JsonNode # can throw errors, used in HTTP

type NexportedFunction = ref object
  fsign:    FnSignatureS
  handler:  NFHandler
  parser:   NFParser
var nexported_functions: OrderedTable[string, NexportedFunction]
var nexported_functions_aliases: OrderedTable[string, NexportedFunction]

proc full_name(s: FnSignatureS): string =
  # Full name with argument types and return values, needed to support multiple dispatch
  template normalize (s: string): string = s.replace("_", "").replace(" ", "").to_lower
  let args_s = s[1].map((arg) => fmt"{arg[0].normalize}: {arg[1].normalize}").join(", ")
  fmt"{s[0].normalize}({args_s}): {s[2].normalize}"

proc register(nf: NexportedFunction): void =
  let full_name = nf.fsign.full_name
  if full_name in nexported_functions: throw fmt"duplicate nexported function {full_name}"
  nexported_functions[full_name] = nf

  # Additionally registering alias with name only, if there's no overrided version
  let name = nf.fsign[0]
  if name in nexported_functions_aliases:
    # There are overrided versions, removing short name
    nexported_functions_aliases.del name
  else:
    nexported_functions_aliases[name] = nf

proc from_string_if_exists*[T](_: type[T], s: string): T =
  when compiles(T.from_string(s)): T.from_string s
  else:                            throw fmt"provide '{$T}.from_string' conversion"


# build_parser -------------------------------------------------------------------------------------
proc build_parser0(fsign: FnSignatureS): NFParser =
  proc parser(list: seq[string], map: Table[string, string]): JsonNode =
    assert list.len + map.len == 0
    let json = newJArray()
    json
  return parser

proc build_parser1[A](fsign: FnSignatureS): NFParser =
  proc parser(list: seq[string], map: Table[string, string]): JsonNode =
    template raw(i: int): string =
      if i < list.len: list[i] else: map[fsign[1][i][0]]
    assert list.len + map.len == 1
    let json = newJArray()
    json.add %(A.from_string_if_exists raw(0))
    json
  return parser

proc build_parser2[A, B](fsign: FnSignatureS): NFParser =
  proc parser(list: seq[string], map: Table[string, string]): JsonNode =
    template raw(i: int): string =
      if i < list.len: list[i] else: map[fsign[1][i][0]]
    assert list.len + map.len == 2
    let json = newJArray()
    json.add %(A.from_string_if_exists raw(0))
    json.add %(B.from_string_if_exists raw(1))
    json
  return parser

proc build_parser3[A, B, C](fsign: FnSignatureS): NFParser =
  proc parser(list: seq[string], map: Table[string, string]): JsonNode =
    template raw(i: int): string =
      if i < list.len: list[i] else: map[fsign[1][i][0]]
    assert list.len + map.len == 3
    let json = newJArray()
    json.add %(A.from_string_if_exists raw(0))
    json.add %(B.from_string_if_exists raw(1))
    json.add %(B.from_string_if_exists raw(2))
    json
  return parser

# nexport_async_function ---------------------------------------------------------------------------
proc nexport_async_function*[R](fsign: FnSignatureS, fn: proc: Future[R]): void =
  proc nfhandler_async(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 0
    let r = await fn()
    return %(is_error: false, result: r)
  NexportedFunction(fsign: fsign, handler: nfhandler_async, parser: build_parser0(fsign)).register

proc nexport_async_function*[A, R](fsign: FnSignatureS, fn: proc(a: A): Future[R]): void =
  proc nfhandler_async(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 1
    let r = await fn(args[0].to(A))
    return %(is_error: false, result: r)
  NexportedFunction(fsign: fsign, handler: nfhandler_async, parser: build_parser1[A](fsign)).register

proc nexport_async_function*[A, B, R](fsign: FnSignatureS, fn: proc(a: A, b: B): Future[R]): void =
  proc nfhandler_async(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 2
    let r = await fn(args[0].to(A), args[1].to(B))
    return %(is_error: false, result: r)
  NexportedFunction(fsign: fsign, handler: nfhandler_async, parser: build_parser2[A, B](fsign)).register

proc nexport_async_function*[A, B, C, R](fsign: FnSignatureS, fn: proc(a: A, b: B, c: C): Future[R]): void =
  proc nfhandler_async(args: JsonNode): Future[JsonNode] {.async.} =
    assert args.kind == JArray and args.len == 3
    let r = await fn(args[0].to(A), args[1].to(B), args[2].to(C))
    return %(is_error: false, result: r)
  NexportedFunction(fsign: fsign, handler: nfhandler_async, parser: build_parser3[A, B, C](fsign)).register


# nexport_async_function ---------------------------------------------------------------------------
# Such complicated wrappers to provide clean error messages without the async stack trace mess

proc to_async_handler(handler_sync: proc (args: JsonNode): JsonNode): NFHandler =
  proc nfhandler_async(args: JsonNode): Future[JsonNode] {.async.} =
    return handler_sync(args)
  return nfhandler_async

proc nexport_function*[R](fsign: FnSignatureS, fn: proc: R): void =
  proc safe_nfhandler(args: JsonNode): JsonNode =
    assert args.kind == JArray and args.len == 0
    try:
      let r = fn()
      %(is_error: false, result: r)
    except Exception as e:
      %(is_error: true, message: e.msg)
  let parser = build_parser0(fsign)
  NexportedFunction(fsign: fsign, handler: safe_nfhandler.to_async_handler, parser: parser).register

proc nexport_function*[A, R](fsign: FnSignatureS, fn: proc(a: A): R): void =
  proc safe_nfhandler(args: JsonNode): JsonNode =
    assert args.kind == JArray and args.len == 1
    try:
      let r = fn(args[0].to(A))
      %(is_error: false, result: r)
    except Exception as e:
      %(is_error: true, message: e.msg)
  let parser = build_parser1[A](fsign)
  NexportedFunction(fsign: fsign, handler: safe_nfhandler.to_async_handler, parser: parser).register

proc nexport_function*[A, B, R](fsign: FnSignatureS, fn: proc(a: A, b: B): R): void =
  proc safe_nfhandler(args: JsonNode): JsonNode =
    assert args.kind == JArray and args.len == 2
    try:
      let r = fn(args[0].to(A), args[1].to(B))
      %(is_error: false, result: r)
    except Exception as e:
      %(is_error: true, message: e.msg)
  let parser = build_parser2[A, B](fsign)
  NexportedFunction(fsign: fsign, handler: safe_nfhandler.to_async_handler, parser: parser).register

proc nexport_function*[A, B, C, R](fsign: FnSignatureS, fn: proc(a: A, b: B, c: C): R): void =
  proc safe_nfhandler(args: JsonNode): JsonNode =
    assert args.kind == JArray and args.len == 3
    try:
      let r = fn(args[0].to(A), args[1].to(B), args[2].to(C))
      %(is_error: false, result: r)
    except Exception as e:
      %(is_error: true, message: e.msg)
  let parser = build_parser3[A, B, C](fsign)
  NexportedFunction(fsign: fsign, handler: safe_nfhandler.to_async_handler, parser: parser).register


# nexport_handler ----------------------------------------------------------------------------------
proc nexport_handler_async*(req: string): Future[Option[string]] {.async.} =
  # Use it to start as RPC server
  try:
    let data = req.parse_json
    let (fname, args) = (data["fn"].get_str, data["args"])
    let nfn =
      if   fname in nexported_functions:         nexported_functions[fname]
      elif fname in nexported_functions_aliases: nexported_functions_aliases[fname]
      else:                                      throw fmt"no nexported function '{fname}'"
    let res = await nfn.handler(args)
    return res.`%`.`$`.some
  except Exception as e:
    return (is_error: true, message: e.msg).`%`.`$`.some

proc nexport_handler_with_parser_async*(
  fname: string, list: seq[string], map: Table[string, string]
): Future[Option[string]] {.async.} =
  # Use it to start as RPC server
  try:
    let nfn =
      if   fname in nexported_functions:         nexported_functions[fname]
      elif fname in nexported_functions_aliases: nexported_functions_aliases[fname]
      else:                                      throw fmt"no nexported function '{fname}'"
    let data = nfn.parser(list, map)
    let res = await nfn.handler(data)
    return res.`%`.`$`.some
  except Exception as e:
    return (is_error: true, message: e.msg).`%`.`$`.some

# nimport_from -------------------------------------------------------------------------------------
macro nimport_from*(address: Address, fn: typed): typed =
  # Import remote function from remote address to be able to call it

  let fsign  = fn_signature(fn)
  let (fname, args, rtype, is_async) = fsign
  let fsigns = fsign.to_s
  let full_name = fsigns.full_name

  # Generating code
  if is_async:
    case args.len:
    of 0:
      quote do:
        proc `fname`*(): Future[`rtype`] =
          `address`.call_nexport_fn_async(`full_name`, typeof `rtype`)
    of 1:
      let (a, at, _) = args[0]
      quote do:
        proc `fname`*(`a`: `at`): Future[`rtype`] =
          `address`.call_nexport_fn_async(`full_name`, `a`, typeof `rtype`)
    of 2:
      let (a, at, _) = args[0]; let (b, bt, _) = args[1]
      quote do:
        proc `fname`*(`a`: `at`, `b`: `bt`): Future[`rtype`] =
          `address`.call_nexport_fn_async(`full_name`, `a`, `b`, typeof `rtype`)
    of 3:
      let (a, at, _) = args[0]; let (b, bt, _) = args[1]; let (c, ct, _) = args[2]
      quote do:
        proc `fname`*(`a`: `at`, `b`: `bt`, `c`: `ct`): Future[`rtype`] =
          `address`.call_nexport_fn_async(`full_name`, `a`, `b`, `c`, typeof `rtype`)
    else:
      quote do:
        raise new_exception(Exception, "not supported, please update the code to suppor it")
  else:
    case args.len:
    of 0:
      quote do:
        proc `fname`*(): `rtype` =
          `address`.call_nexport_fn(`full_name`, typeof `rtype`)
    of 1:
      let (a, at, _) = args[0]
      quote do:
        proc `fname`*(`a`: `at`): `rtype` =
          `address`.call_nexport_fn(`full_name`, `a`, typeof `rtype`)
    of 2:
      let (a, at, _) = args[0]; let (b, bt, _) = args[1]
      quote do:
        proc `fname`*(`a`: `at`, `b`: `bt`): `rtype` =
          `address`.call_nexport_fn(`full_name`, `a`, `b`, typeof `rtype`)
    of 3:
      let (a, at, _) = args[0]; let (b, bt, _) = args[1]; let (c, ct, _) = args[2]
      quote do:
        proc `fname`*(`a`: `at`, `b`: `bt`, `c`: `ct`): `rtype` =
          `address`.call_nexport_fn(`full_name`, `a`, `b`, `c`, typeof `rtype`)
    else:
      quote do:
        raise new_exception(Exception, "not supported, please update the code to suppor it")


# call_nexport_fn ----------------------------------------------------------------------------------
proc call_nexport_fn(address: Address, fname: string, args: JsonNode): JsonNode =
  assert args.kind == JArray
  let res = try:
    address.call((fn: fname, args: args).`%`.`$`)
  except Exception as e:
    throw fmt"can't call '{address}.{fname}', {e.msg}"
  let data = res.parse_json
  if data["is_error"].get_bool: throw data["message"].get_str
  data["result"]

proc call_nexport_fn*[R](address: Address, fname: string, rtype: type[R]): R =
  let args = newJArray()
  call_nexport_fn(address, fname, args).to(R)

proc call_nexport_fn*[A, R](address: Address, fname: string, a: A, tr: type[R]): R =
  let args = newJArray(); args.add %a;
  call_nexport_fn(address, fname, args).to(R)

proc call_nexport_fn*[A, B, R](address: Address, fname: string, a: A, b: B, tr: type[R]): R =
  let args = newJArray(); args.add %a; args.add %b;
  call_nexport_fn(address, fname, args).to(R)

proc call_nexport_fn*[A, B, C, R](address: Address, fname: string, a: A, b: B, c: C, tr: type[R]): R =
  let args = newJArray(); args.add %a; args.add %b; args.add %c
  call_nexport_fn(address, fname, args).to(R)


# call_nexport_fn_async -----------------------------------------------------------------------------
proc call_nexport_fn_async(address: Address, fname: string, args: JsonNode): Future[JsonNode] {.async.} =
  assert args.kind == JArray
  let res = try:
    await address.call_async((fn: fname, args: args).`%`.`$`)
  except Exception as e:
    throw fmt"can't call '{address}.{fname}', {e.msg}"
  let data = res.parse_json
  if data["is_error"].get_bool: throw data["message"].get_str
  return data["result"]

proc call_nexport_fn_async*[R](
  address: Address, fname: string, tr: type[R]
): Future[R] {.async.} =
  let args = newJArray();
  return (await call_nexport_fn_async(address, fname, args)).to(R)

proc call_nexport_fn_async*[A, R](
  address: Address, fname: string, a: A, tr: type[R]
): Future[R] {.async.} =
  let args = newJArray(); args.add %a
  return (await call_nexport_fn_async(address, fname, args)).to(R)

proc call_nexport_fn_async*[A, B, R](
  address: Address, fname: string, a: A, b: B, tr: type[R]
): Future[R] {.async.} =
  let args = newJArray(); args.add %a; args.add %b;
  return (await call_nexport_fn_async(address, fname, args)).to(R)

proc call_nexport_fn_async*[A, B, C, R](
  address: Address, fname: string, a: A, b: B, c: C, tr: type[R]
): Future[R] {.async.} =
  let args = newJArray(); args.add %a; args.add %b; args.add %c
  return (await call_nexport_fn_async(address, fname, args)).to(R)

# generate_nimport ---------------------------------------------------------------------------------
proc generate_nimport*(
  folder:   string,
  address:  Address,
  as_async: Option[bool],
  prepend:  Option[string]
): void =
  # Generates nimported functions
  # By default sync/async would be same as in nexported function, it could be changed with `as_async`
  var statements: seq[string]

  # Addin imports and address
  let default_prepend = fmt"""
    # Auto-generated code, do not edit
    import nodem, asyncdispatch
    export nodem, asyncdispatch

    let {address}* = Address("{address}")""".dedent
  statements.add prepend.get(default_prepend)

  # Addin nexported functions
  for nfn in nexported_functions.values:
    let fsign = nfn.fsign
    let is_async = as_async.get fsign[3]

    # Declaring function
    let args_s = fsign[1].map((arg) => fmt"{arg[0]}: {arg[1]}").join(", ")
    statements.add if is_async:
      fmt"proc {fsign[0]}*({args_s}): Future[{fsign[2]}]" & " {.nimport_from: " & $address & ".} = discard"
    else: # sync
      fmt"proc {fsign[0]}*({args_s}): {fsign[2]}" & " {.nimport_from: " & $address & ".} = discard"

  let code = statements.join("\n\n")

  # Avoiding writing file if it's the same
  let path = folder / fmt"{address}i.nim"
  let existing_code =
    try: read_file(path)
    except: ""

  if existing_code != code:
    write_file(path, code)

template generate_nimport*(address: Address, as_async: bool): void =
  let folder = instantiation_info(full_paths = true).filename.parent_dir
  generate_nimport(folder, address, as_async.some, string.none)

template generate_nimport*(address: Address): void =
  let folder = instantiation_info(full_paths = true).filename.parent_dir
  generate_nimport(folder, address, bool.none, string.none)


# run ----------------------------------------------------------------------------------------------
proc run*(address: Address) =
  async_check address.receive_async(nexport_handler_async)
  run_forever()