import json, uri, strutils, os


# parse_url ----------------------------------------------------------------------------------------
proc parse_url*(url: string): tuple[scheme: string, host: string, port: int] =
  var parsed = init_uri()
  parse_uri(url, parsed)
  (parsed.scheme, parsed.hostname, parsed.port.parse_int)


# throw --------------------------------------------------------------------------------------------
template throw*(message: string) = raise newException(Exception, message)


proc `%`*[T: tuple](o: T): JsonNode =
  result = new_JObject()
  for k, v in o.field_pairs: result[k] = %v


# test ---------------------------------------------------------------------------------------------
let test_enabled_s = get_env("test", "false")
let test_enabled   = test_enabled_s == "true"

template test*(name: string, body) =
  # block:
  if test_enabled or test_enabled_s == name.to_lower:
    try:
      body
    except Exception as e:
      echo "test '", name.to_lower, "' failed"
      raise e