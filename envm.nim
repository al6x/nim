import strformat, macros, sugar, strutils, os, tables


# Helper -------------------------------------------------------------------------------------------
template throw*(message: string) = raise newException(CatchableError, message)


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
proc parse_string_as(v: string, _: float): float = v.parse_float
proc parse_string_as(v: string, _: string): string = v
proc parse_string_as(v: string, _: bool): bool = v.to_lower in ["true", "yes"]


# parse_env ----------------------------------------------------------------------------------------
proc parse_env*[T: tuple|object](
  _: type[T], default: T, required_args = (0, 0), required_options: openarray[string] = [], env = env
): (T, seq[string]) =
  var o = default

  # List of keys in object
  var object_keys: seq[string]
  for k, v in o.field_pairs: object_keys.add k

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
      elif token.normalize_key in object_keys or token.normalize_key in special_arguments:
        # Non key/value argument with name matching `T.key` treating as boolean key/value
        options[token.normalize_key] = "true"
      else:
        args.add token

  block: # Printing help
    if "help" in options and options["help"] == "true":
      echo "Help:"
      echo "  options:"
      for k, v in special_arguments:
        echo fmt"    - {k}, {v}"
      for k, v in o.field_pairs:
        echo "    - " & k & ", " & $(typeof v) & (if k in required_options: ", required" else: "")
      if required_args[1] > 0:
        if required_args[1] == required_args[0]:
          echo fmt"  arguments count {required_args[0]}"
        else:
          echo fmt"  arguments count {required_args[0]}..{required_args[1]}"
      quit(0)

  block: # Validating args
    if args.len < required_args[0] or args.len > required_args[1]:
      throw fmt"Expected {required_args[0]}..{required_args[1]} arguments, but got {args.len}"
    for k, _ in options:
      if k notin object_keys and k notin special_arguments:
        throw fmt"Unknown option '{k}'"

    func ktype(k: string): string =
      for k2, v in o.field_pairs:
        if k == k2: return $(typeof v)
      throw fmt"Invalid '{k}'"
    for k in required_options:
      if k notin options:
        throw fmt"Option '{k}', {ktype(k)}, required"

  # Parsing and casting into object
  for k, v in o.field_pairs:
    if k in options: v = parse_string_as(options[k], v)
    elif k in env:   v = parse_string_as(env[k], v)

  (o, args)


# Test ---------------------------------------------------------------------------------------------
# nim c -r envm.nim file=a.txt lines=2 something
if is_main_module:
  type Config = object
    file:  string
    lines: int

  echo Config.parse_env(Config(file: "", lines: 2), required_options = ["file"], required_args = (1, 2))