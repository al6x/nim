import json, uri, strutils, os, re, sugar, tables
from times as nt import nil


template throw*(message: string) = raise new_exception(Exception, message)


proc parse_url*(url: string): tuple[scheme: string, host: string, port: int, path: string] =
  var parsed = init_uri()
  parse_uri(url, parsed)
  (parsed.scheme, parsed.hostname, parsed.port.parse_int, parsed.path)


proc `%`*[T: tuple](o: T): JsonNode =
  result = new_JObject()
  for k, v in o.field_pairs: result[k] = %v


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

type Timer* = proc: int
proc timer_ms*(): Timer =
  let started_at = nt.utc(nt.now())
  () => nt.in_milliseconds(nt.`-`(nt.utc(nt.now()), started_at)).int

proc quit*(e: ref Exception) =
  stderr.write_line e.msg
  stderr.write_line e.get_stack_trace
  quit 1

const p* = echo

proc values*[K, V](table: Table[K, V] | ref Table[K, V]): seq[V] =
  for v in table.values: result.add v

proc values*[K, V](table: OrderedTable[K, V] | ref OrderedTable[K, V]): seq[V] =
  for v in table.values: result.add v