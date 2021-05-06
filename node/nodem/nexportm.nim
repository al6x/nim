import basem, jsonm, macros, envm
import ./parserm, ./nodem

export jsonm, parserm, nodem


# fn_signature -------------------------------------------------------------------------------------
type FnSignature* = (NimNode, seq[(NimNode, NimNode, NimNode)], NimNode, bool)
#                  (fname,       [aname,   atype,   adefault], rtype,   async)
# `NimNodes` have are of `nnk_sym` except of `arg_default` which is `nnk_empty` or custom literal type.

type FnSignatureS* = (string, seq[(string, string, Option[string])], string, bool)
proc to_s*(fsign: FnSignature): FnSignatureS =
  let args = fsign[1].map((arg) => (
    arg[0].str_val, arg[1].str_val, if arg[2].kind == nnk_empty: string.none else: arg[2].str_val.some)
  )
  (fsign[0].str_val, args, fsign[2].repr, fsign[3])

proc fn_signature*(fn_raw: NimNode): FnSignature =
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
  of nnk_bracket_expr: # Generic
    if rnode[0].str_val == "Future": # async fn
      assert rnode.len == 2, invalid_usage
      (rnode[1], true)
    else:
      (rnode, false)
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

  if is_async: throw "async functions not supported"
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
type NFHandler = proc (args: JsonNode): JsonNode # can throw errors
type NFParser = proc (
  cnode: JsonNode, positional: seq[string], named: Table[string, string], named_json: JsonNode
): JsonNode
# Parses any combination of arguments, positional, named or named in json

type NexportedFunction* = ref object
  fsign*:    FnSignatureS
  handler*:  NFHandler
  parser*:   NFParser
var nexported_functions*: OrderedTable[string, NexportedFunction]
var nexported_functions_aliases: OrderedTable[string, NexportedFunction]

proc normalize_symbol(s: string): string = s.replace("_", "").replace(" ", "")

proc full_name*(s: FnSignatureS): string =
  # Full name with argument types and return values, needed to support multiple dispatch
  # For node arg always using name `node`.
  let node_arg_s = fmt"node: {s[1][0][1].normalize_symbol}"
  let args_s = s[1][1..^1].map((arg) => fmt"{arg[0].normalize_symbol}: {arg[1].normalize_symbol}").join(", ")
  fmt"{s[0].normalize_symbol}({node_arg_s}, {args_s}): {s[2].normalize_symbol}"

proc short_name*(s: FnSignatureS): string =
  s[0].normalize_symbol

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


# build_parser -------------------------------------------------------------------------------------
proc from_string_if_exists*[T](_: type[T], s: string): T =
  when compiles(T.from_string(s)): T.from_string s
  else:                            throw fmt"provide '{$T}.from_string' conversion"

proc parse_arg[T](
  _: type[T], fsign: FnSignatureS, i: int, positional: seq[string],
  named: Table[string, string], named_json: JsonNode
): T =
  let arg_name = fsign[1][i + 1][0]
  if   i < positional.len:
    T.from_string_if_exists positional[i]
  elif arg_name in named:
    T.from_string_if_exists named[arg_name]
  elif arg_name in named_json:
    named_json[arg_name].to(T)
  else:
    throw fmt"argument '{arg_name}' not defined for {fsign[0]}"

proc build_parser0(fsign: FnSignatureS): NFParser =
  proc parser(
    cnode: JsonNode, positional: seq[string], named: Table[string, string], named_json: JsonNode
  ): JsonNode =
    assert positional.len + named.len + named_json.len == 0
    let json = newJArray()
    json.add cnode
    json
  return parser

proc build_parser1[A](fsign: FnSignatureS): NFParser =
  proc parser(
    cnode: JsonNode, positional: seq[string], named: Table[string, string], named_json: JsonNode
  ): JsonNode =
    assert positional.len + named.len + named_json.len == 1
    let json = newJArray()
    json.add cnode
    json.add %(A.parse_arg(fsign, 0, positional, named, named_json))
    json
  return parser

proc build_parser2[A, B](fsign: FnSignatureS): NFParser =
  proc parser(
    cnode: JsonNode, positional: seq[string], named: Table[string, string], named_json: JsonNode
  ): JsonNode =
    assert positional.len + named.len + named_json.len == 2
    let json = newJArray()
    json.add cnode
    json.add %(A.parse_arg(fsign, 0, positional, named, named_json))
    json.add %(B.parse_arg(fsign, 1, positional, named, named_json))
    json
  return parser

proc build_parser3[A, B, C](fsign: FnSignatureS): NFParser =
  proc parser(
    cnode: JsonNode, positional: seq[string], named: Table[string, string], named_json: JsonNode
  ): JsonNode =
    assert positional.len + named.len + named_json.len == 3
    let json = newJArray()
    json.add cnode
    json.add %(A.parse_arg(fsign, 0, positional, named, named_json))
    json.add %(B.parse_arg(fsign, 1, positional, named, named_json))
    json.add %(C.parse_arg(fsign, 2, positional, named, named_json))
    json
  return parser


# nexport_function ---------------------------------------------------------------------------
proc nexport_function*[N, R](fsign: FnSignatureS, fn: proc(n: N): R): void =
  proc nfhandler(args: JsonNode): JsonNode =
    assert args.kind == JArray and args.len == 0
    %fn(args[0].to(N))
  NexportedFunction(fsign: fsign, handler: nfhandler, parser: build_parser0(fsign)).register

proc nexport_function*[N, A, R](fsign: FnSignatureS, fn: proc(n: N, a: A): R): void =
  proc nfhandler(args: JsonNode): JsonNode =
    assert args.kind == JArray and args.len == 2
    %fn(args[0].to(N), args[1].to(A))
  NexportedFunction(fsign: fsign, handler: nfhandler, parser: build_parser1[A](fsign)).register

proc nexport_function*[N, A, B, R](fsign: FnSignatureS, fn: proc(n: N, a: A, b: B): R): void =
  proc nfhandler(args: JsonNode): JsonNode =
    assert args.kind == JArray and args.len == 3
    %fn(args[0].to(N), args[1].to(A), args[2].to(B))
  NexportedFunction(fsign: fsign, handler: nfhandler, parser: build_parser2[A, B](fsign)).register

proc nexport_function*[N, A, B, C, R](fsign: FnSignatureS, fn: proc(n: N, a: A, b: B, c: C): R): void =
  proc nfhandler(args: JsonNode): JsonNode =
    assert args.kind == JArray and args.len == 4
    %fn(args[0].to(N), args[1].to(A), args[2].to(B), args[3].to(C))
  NexportedFunction(fsign: fsign, handler: nfhandler, parser: build_parser3[A, B, C](fsign)).register

# For void
proc nexport_function*[N, A](fsign: FnSignatureS, fn: proc(n: N, a: A): void): void =
  nexport_function(fsign, proc(n: N, a: A): string = fn(n, a))

proc nexport_function*[N](fsign: FnSignatureS, fn: proc(n: N): void): void =
  nexport_function(fsign, proc(n: N): string = fn(n))

proc nexport_function*[N, A, B](fsign: FnSignatureS, fn: proc(n: N, a: A, b: B): void): void =
  nexport_function(fsign, proc(n: N, a: A, b: B): string = fn(n, a, b))

proc nexport_function*[N, A, B, C](fsign: FnSignatureS, fn: proc(n: N, a: A, b: B, c: C): void): void =
  nexport_function(fsign, proc(n: N, a: A, b: B, c: C): string = fn(n, a, b, c))


# nexport_async_function ---------------------------------------------------------------------------
var catch_node_errors* = env.is_production()
# Should be true in production, but in development it's better to set it as false


# call_nexport_function ----------------------------------------------------------------------------
proc call_nexport_function*(req_json: string): Option[string] =
  # `req_json` - json in form `{ fn: "plus", args: [2, 3] }`
  try:
    let data = req_json.parse_json
    let (fname, args) = (data["fn"].get_str, data["args"])
    let nfn =
      if   fname in nexported_functions:         nexported_functions[fname]
      elif fname in nexported_functions_aliases: nexported_functions_aliases[fname]
      else:                                      throw fmt"no nexported function '{fname}'"
    nfn.handler(args).`$`.some
  except Exception as e:
    if not catch_node_errors: quit(e)
    (is_error: true, message: e.msg).`%`.`$`.some

proc call_nexport_function*(
  fname: string, cnode: JsonNode, positional: seq[string], named: Table[string, string], named_json: JsonNode
): Option[string] =
  # Calls nexported function with raw string arguments, arguments would be parsed and casted to correct types,
  # positional and named arguments could be mixed.
  try:
    let nfn =
      if   fname in nexported_functions:         nexported_functions[fname]
      elif fname in nexported_functions_aliases: nexported_functions_aliases[fname]
      else:                                      throw fmt"no nexported function '{fname}'"

    var args = nfn.parser(cnode, positional, named, named_json)
    nfn.handler(args).`$`.some
  except Exception as e:
    if not catch_node_errors: quit(e)
    (is_error: true, message: e.msg).`%`.`$`.some