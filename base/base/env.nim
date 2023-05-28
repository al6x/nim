import std/[strformat, macros, sugar, strutils, os, tables, options]
from ./terminal as terminal import nil

# Checking required language features --------------------------------------------------------------
template try_define_overloadable_enums = # Checking if `--experimental:overloadable_enums` enabled
  block:
    type EA = enum e1
    type EB = enum e1

when not compiles(try_define_overloadable_enums()):
# when not defined(nim_has_overloadable_enums):
  static:
    echo "Error: nim experimental feature required, run nim with `--experimental:overloadable_enums` flag."
    quit(1)

# Helper -------------------------------------------------------------------------------------------
template throw(message: string) =
  raise newException(Exception, message)


# Env ----------------------------------------------------------------------------------------------
type Env* = Table[string, string]

let env* = block:
  var env = Env()
  for (k, v) in env_pairs(): env[k] = v

  # Adding arguments from command line
  for i in (1..param_count()):
    let token = param_str(i)
    if not token.starts_with("\""):
      if "=" in token:
        let pair = token.split("=", 2)
        # Keys are normalized, lowercased with replaced `_`
        env[pair[0]] = pair[1]
      else:
        # Non key/value argument with name matching `T.key` treating as boolean key/value
        env[token] = "true"
  env

proc `[]`*(env: Env, key: string, default: string): string =
  if key in env: env[key] else: default

# Test ---------------------------------------------------------------------------------------------
# nim c -r base/base/env.nim test
if is_main_module:
  echo env["test", "false"]


# const special_arguments = { "help": "bool" }.to_table

# Normalizing keys, so both camel case and underscore keys will be matched
# func normalize_key(v: string): string = v.to_lower.replace("_", "")

# contains -----------------------------------------------------------------------------------------
# proc contains*(env: Env, key: string): bool =
#   key.normalize_key in env.values

# [], get_optional ---------------------------------------------------------------------------------
# proc get_optional*(env: Env, key: string): Option[string] =
#   let normalized = key.normalize_key
#   if normalized in env.values: env.values[key.normalize_key].some else: string.none

# proc `[]`*(env: Env, key: string): string =
#   let normalized = key.normalize_key
#   if normalized in env.values: env.values[key.normalize_key] else: throw fmt"no environment variable '{key}'"

# environment mode ---------------------------------------------------------------------------------
# let env_mode = env["env", "dev"]
# if env_mode notin ["dev", "test", "prod"]: throw fmt"invalid env mode {env_mode}"
# proc is_prod*(env: Env): bool = env_mode == "prod"
# proc is_test*(env: Env): bool = env_mode == "test"
# proc is_dev*(env: Env): bool  = env_mode == "dev"
