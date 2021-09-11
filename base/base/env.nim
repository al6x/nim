import std/[strformat, macros, sugar, strutils, os, tables, options]
from ./terminal as terminal import nil


# Helper -------------------------------------------------------------------------------------------
template throw(message: string) = raise newException(Exception, message)


# Env ----------------------------------------------------------------------------------------------
type Env* = ref object
  values*: Table[string, string]

const special_arguments = { "help": "bool" }.to_table

# Normalizing keys, so both camel case and underscore keys will be matched
func normalize_key(v: string): string = v.to_lower.replace("_", "")

let env* = block:
  var result = Env()
  for (k, v) in env_pairs(): result.values[k.normalize_key] = v

  # Adding arguments from command line
  for i in (1..param_count()):
    let token = param_str(i)
    if not token.starts_with("\""):
      if "=" in token:
        let pair = token.split("=", 2)
        # Keys are normalized, lowercased with replaced `_`
        result.values[pair[0].normalize_key] = pair[1]
      elif token.normalize_key in special_arguments:
        # Non key/value argument with name matching `T.key` treating as boolean key/value
        result.values[token.normalize_key] = "true"

  result

# contains -----------------------------------------------------------------------------------------
proc contains*(env: Env, key: string): bool =
  key.normalize_key in env.values

# [], get_optional ---------------------------------------------------------------------------------
proc get_optional*(env: Env, key: string): Option[string] =
  let normalized = key.normalize_key
  if normalized in env.values: env.values[key.normalize_key].some else: string.none

proc `[]`*(env: Env, key: string): string =
  let normalized = key.normalize_key
  if normalized in env.values: env.values[key.normalize_key] else: throw fmt"no environment variable '{key}'"

proc `[]`*(env: Env, key: string, default: string): string =
  env.get_optional(key).get(default)

# environment mode ---------------------------------------------------------------------------------
let env_mode = env["env", "dev"]
if env_mode notin ["dev", "test", "prod"]: throw fmt"invalid env mode {env_mode}"
proc is_prod*(env: Env): bool = env_mode == "prod"
proc is_test*(env: Env): bool = env_mode == "test"
proc is_dev*(env: Env): bool  = env_mode == "dev"


# parse_env_variable -------------------------------------------------------------------------------
proc parse_string_as(_: type[int],    v: string): int    = v.parse_int
proc parse_string_as(_: type[float],  v: string): float  = v.parse_float
proc parse_string_as(_: type[string], v: string): string = v
proc parse_string_as(_: type[bool],   v: string): bool   = v.to_lower in ["true", "yes"]


# parse_env ----------------------------------------------------------------------------------------
proc parse_env*[T: tuple|object](
  _:                type[T],
  default:          T,
  required_args                       = (0, 0),
  required_options: openarray[string] = [],
  env                                 = env
): (T, seq[string]) = # (options, args)
  var o = default

  # List of keys in object
  var object_keys, normalized_object_keys: seq[string]
  for k, v in o.field_pairs:
    object_keys.add k
    normalized_object_keys.add k.normalize_key

  # Parsing command line arguments
  var options: Table[string, string]
  var args: seq[string]
  for i in (1..param_count()):
    let token = param_str(i)
    if token.starts_with("\""):
      args.add token
    else:
      if "=" in token:
        let pair = token.split("=", 2)
        # Keys are normalized, lowercased with replaced `_`
        options[pair[0].normalize_key] = pair[1]
      elif token.normalize_key in normalized_object_keys or token.normalize_key in special_arguments:
        # Non key/value argument with name matching `T.key` treating as boolean key/value
        options[token.normalize_key] = "true"
      else:
        args.add token

  block: # Printing help
    if "help" in options and options["help"] == "true":
      if required_args[1] > 0:
        if required_args[1] == required_args[0]:
          echo fmt"arguments count {required_args[0]}"
        else:
          echo fmt"arguments count {required_args[0]}..{required_args[1]}"

      for k, v in o.field_pairs:
        echo "  - " & k & ", " & $(typeof v) & (if k in required_options: ", required" else: "")
      echo ""
      for k, v in special_arguments:
        echo terminal.grey(fmt"  - {k}, {v}")

      quit(0)

  block: # Validating args
    if required_args[1] == 0 and args.len > 0:
      throw fmt"Expected no arguments, but got {args.len}"
    if args.len < required_args[0] or args.len > required_args[1]:
      throw fmt"Expected {required_args[0]}..{required_args[1]} arguments, but got {args.len}"
    for k, _ in options:
      if k notin normalized_object_keys and k notin special_arguments:
        throw fmt"Unknown option '{k}'"

    func ktype(k: string): string =
      for k2, v in o.field_pairs:
        if k == k2: return $(typeof v)
      throw fmt"Invalid '{k}'"
    for k in required_options:
      if k.normalize_key notin options:
        throw fmt"Option '{k}', {ktype(k)}, required"

  # Parsing and casting into object
  for k, v in o.field_pairs:
    let nk = k.normalize_key
    if nk in options:      v = parse_string_as(typeof v, options[nk])
    elif nk in env.values: v = parse_string_as(typeof v, env.values[nk])

  (o, args)


# Test ---------------------------------------------------------------------------------------------
# nim c -r envm.nim file=a.txt some_flag lines=2 something
if is_main_module:
  type Config = object
    file:      string
    lines:     int
    some_flag: bool

  echo Config.parse_env(
    default          = Config(file: "", lines: 2, some_flag: false),
    required_options = ["file"],
    required_args    = (1, 2)
  )