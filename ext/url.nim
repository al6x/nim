from std/uri as nurim import nil
import base

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
  Url(is_full: false, path: npath, query: nquery)

proc init*(
  _: type[Url], scheme = "http", host: string, port = 80, path = "", query = init_table[string, string]()
): Url =
  let rel = Url.init(path, query)
  Url(is_full: true, scheme: scheme, host: host, port: port, path: rel.path, query: rel.query)

proc init*(_: type[Url], nuri: nurim.Uri): Url =
  var query: Table[string, string]
  for _, (k, v) in sequtils.to_seq(nurim.decode_query(nuri.query)): query[k] = v
  let is_full = nuri.hostname != ""
  if is_full:
    let port_s = if nuri.port == "": "80" else: nuri.port
    Url.init(scheme = nuri.scheme, host = nuri.hostname, port = port_s.parse_int,
      path = nuri.path, query = query)
  else:
    Url.init(path = nuri.path, query = query)

proc parse*(_: type[Url], url: string): Url =
  var parsed = nurim.init_uri()
  nurim.parse_uri(url, parsed)
  Url.init parsed

proc hash*(url: Url): Hash = url.autohash

proc `==`*(a, b: Url): bool =
  # auto equality doesn't work for case objects
  a.path == b.path and a.query == b.query and (
    if not a.is_full: not b.is_full
    else:             (b.is_full and a.scheme == b.scheme and a.host == b.host and a.port == b.port)
  )

proc `$`*(url: Url): string =
  var query: seq[(string, string)]
  for k, v in url.query: query.add (k, v)
  query = query.sort (kv) => kv[0]
  var query_s = if query.len > 0: "?" & nurim.encode_query(query) else: ""
  if url.is_full:
    let port   = if url.port == 80: "" else: fmt":{url.port}"
    let scheme = if url.scheme.is_empty: "" else: fmt"{url.scheme}://"
    fmt"{scheme}{url.host}{port}{url.path}{query_s}"
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
  result.path  = base.path.replace(re"/^", "") & addon.path
  result.query = base.query & addon.query

proc `&`*(base: Url, addon: string): Url =
  base & Url.parse(addon)

proc path_parts*(self: Url): seq[string] =
  self.path.split("/").reject(is_empty)

proc subdomain*(host: string): Option[string] =
  re"^([^\.]+)\.".parse(host).map((found) => found[0])

proc to_json_hook*(url: Url): JsonNode =
  url.to_s.to_json

proc from_json_hook*(v: var Url, json: JsonNode) =
  v = Url.parse json.get_str

test "parse, path, query":
  let url_s = "http://host.com/path?a=b&c=d"
  let url = Url.parse url_s
  check url.to_s == url_s
  check url.path == "/path"
  check url.query == {"c": "d", "a": "b"}.to_table

test "json":
  let url = Url.parse "http://host.com/path?a=b&c=d"
  let jsons = url.to_json.to_s
  let parsed = jsons.parse_json.json_to(Url)
  check url == parsed