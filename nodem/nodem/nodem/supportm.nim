import json, strutils, strformat, os, re, sugar, tables, options, sequtils, macros
from uri import nil
from times as nt import nil
import ./support_httpm

export support_httpm

template throw*(message: string) = raise new_exception(Exception, message)


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

# Merge two tables, same keys in the first table will be overwritten
proc `&`*[K, V](a, b: Table[K, V] | ref Table[K, V]): Table[K, V] =
  for k, v in a: result[k] = v
  for k, v in b: result[k] = v


# Url ----------------------------------------------------------------------------------------------
# proc build_url*(url: string, query: varargs[(string, string)]): string =
#   if query.len > 0: url & "?" & query.encode_query
#   else:            url

# proc build_url*(url: string, query: tuple): string =
#   var squery: seq[(string, string)] = @[]
#   for k, v in query.field_pairs: squery.add((k, $v))
#   build_url(url, squery)

type Url* = object
  path*:   string
  query*:  Table[string, string]
  case is_full*: bool
  of true:
    scheme*: string
    host*:   string
    port*:   int
  else:
    discard

proc init*(_: type[Url], path = "", query = init_table[string, string]()): Url =
  # Normalising
  # assert path == "" or path.starts_with("/")
  var npath = path.replace(re"/$", "")
  var nquery: Table[string, string]
  for k, v in query:
    if k != "" and v != "": nquery[k] = v
  if path == "" and nquery.len == 0: throw "url is empty"
  Url(is_full: false, path: npath, query: nquery)

proc init*(
  _: type[Url], scheme = "http", host: string, port = 80, path = "", query = init_table[string, string]()
): Url =
  let rel = Url.init(path, query)
  Url(is_full: true, scheme: scheme, host: host, port: port, path: rel.path, query: rel.query)

proc parse*(_: type[Url], url: string): Url =
  var parsed = uri.init_uri()
  uri.parse_uri(url, parsed)
  var query: Table[string, string]
  for k, v in decode_query(parsed.query): query[k] = v
  let is_full = parsed.hostname != ""
  if is_full:
    let port_s = if parsed.port == "": "80" else: parsed.port
    Url.init(scheme = parsed.scheme, host = parsed.hostname, port = port_s.parse_int,
      path = parsed.path, query = query)
  else:
    Url.init(path = parsed.path, query = query)

proc `$`*(url: Url): string =
  var query: seq[(string, string)]
  for k, v in url.query: query.add (k, v)
  var query_s = if query.len > 0: "?" & uri.encode_query(query) else: ""
  if url.is_full:
    let port = if url.port == 80: "" else: fmt":{url.port}"
    fmt"{url.scheme}://{url.host}{port}{url.path}{query_s}"
  else:
    fmt"{url.path}{query_s}"

# Merge two urls
proc `&`*(base, addon: Url): Url =
  if base.is_full and addon.is_full:
    assert base.scheme == addon.scheme and base.host == addon.host and base.port == addon.port
  elif base.is_full and not addon.is_full:
    discard
  elif not base.is_full and addon.is_full:
    throw "can't merge full url {addon} into partial url {base}"
  result = base
  result.path  = base.path.replace(re"/^") & addon.path
  result.query = base.query & addon.query