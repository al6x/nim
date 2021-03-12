import strformat, macros, sugar, strutils, os, tables

# Env ----------------------------------------------------------------------------------------------
type Env = Table[string, string]

const special_arguments = { "help": "bool", "test": "string" }.to_table

# Normalizing keys, so both camel case and underscore keys will be matched
func normalize_key(v: string): string = v.to_lower.replace("_", "")

let env* = block:
  var result: Env
  for (k, v) in env_pairs(): result[k.normalize_key] = v

  # Adding arguments from command line
  for i in (1..param_count()):
    let token = param_str(i)
    if not token.starts_with("\""):
      if "=" in token:
        let pair = token.split("=", 2)
        # Keys are normalized, lowercased with replaced `_`
        result[pair[0].normalize_key] = pair[1]
      elif token.normalize_key in special_arguments:
        # Non key/value argument with name matching `T.key` treating as boolean key/value
        result[token.normalize_key] = "true"

  result


# parse_env_variable -------------------------------------------------------------------------------
proc parse_string_as(v: string, _: int): int = v.parse_int
proc parse_string_as(v: string, _: string): string = v
proc parse_string_as(v: string, _: bool): bool = v.to_lower in ["true", "yes"]


# parse_env ----------------------------------------------------------------------------------------
proc parse_env*[T: tuple|object](
  _: type[T], default: T, args_count = (0, 0), env = env
): (T, seq[string]) =
  var o = default

  # List of keys in object
  var object_keys: seq[string]
  for k, v in o.field_pairs: object_keys.add k

  # Parsing command line arguments
  var kvargs: Table[string, string]
  var args: seq[string]
  for i in (1..param_count()):
    let token = param_str(i)
    if token.starts_with("\""):
      args.add token
    else:
      if "=" in token:
        let pair = token.split("=", 2)
        # Keys are normalized, lowercased with replaced `_`
        kvargs[pair[0].normalize_key] = pair[1]
      elif token.normalize_key in object_keys or token.normalize_key in special_arguments:
        # Non key/value argument with name matching `T.key` treating as boolean key/value
        kvargs[token.normalize_key] = "true"
      else:
        args.add token

  block: # Printing help
    if "help" in kvargs and kvargs["help"] == "true":
      echo "Help:"
      echo "  options:"
      for k, v in special_arguments:
        echo fmt"    {k} {v}"
      for k, v in o.field_pairs:
        echo "    " & k & " " & $(typeof v)
      if args_count[1] > 0:
        if args_count[1] == args_count[0]:
          echo fmt"  arguments count {args_count[0]}"
        else:
          echo fmt"  arguments count {args_count[0]}..{args_count[1]}"
      quit(0)

  block: # Validating args
    if args.len < args_count[0] or args.len > args_count[1]: raise newException(CatchableError,
      fmt"Expected {args_count[0]}..{args_count[1]} arguments, but got {args.len}"
    )
    for k, _ in kvargs:
      if k notin object_keys and k notin special_arguments:
        raise newException(CatchableError, fmt"Unknown option '{k}'")

  # Parsing and casting into object
  for k, v in o.field_pairs:
    if k in kvargs: v = parse_string_as(kvargs[k], v)
    elif k in env:  v = parse_string_as(env[k], v)

  (o, args)


# Test ---------------------------------------------------------------------------------------------
# nim c -r envm.nim file=a.txt lines=2 something
if is_main_module:
  type Config = object
    file:  string
    lines: int

  echo Config.parse_env(Config(file: "", lines: 2), args_count = (1, 2))