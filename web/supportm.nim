import basem, logm, timem

import logging, mimetypes, os
import md5

proc log(): Log = Log.init "HTTP"


# Ensuring HttpBeast is not used, as it requires GCSafe --------------------------------------------
if not defined(useStdLib):
  log().error "define useStdLib, otherwise HttpBeast will be used and Bon server not support multithreading"


# escape_html --------------------------------------------------------------------------------------
const ESCAPE_HTML_MAP = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  """: "&quot;",
  """: "&#39;"
}.to_table

func escape_html*(html: string): string =
  html.replace(re"""[&<>'"]""", (c) => ESCAPE_HTML_MAP[c])

test "escape_html":
  assert escape_html("<div>") == """&lt;div&gt;"""


# ignore_request -----------------------------------------------------------------------------------
proc ignore_request*(path: string): bool =
  path in @["/favicon.ico"]

# Disabling logging --------------------------------------------------------------------------------
type VoidLogger* = ref object of Logger

method log*(logger: VoidLogger, level: Level, args: varargs[string, `$`]) = discard

add_handler(VoidLogger())


# route_to_pattern ---------------------------------------------------------------------------------
# Rewrites `"/users/:name/profile/"` as `re"/users/(?<name>[^/]+)/profile"`
proc route_pattern_to_re(route: string): Regex =
  var route = if route == "/": "" else: route
  let pattern_str = route.replace(re"(:[a-z0-9_]+)", proc (match: string): string =
    let name = match.replace(":", "")
    fmt"(?<{name}>[^/]+)"
  )
  re("^" & pattern_str & "$")

test "route_pattern_to_re":
  assert route_pattern_to_re("/users/:name/profile").parse_named("/users/alex/profile") ==
    { "name": "alex" }.to_table


# route_prefix -------------------------------------------------------------------------------------
# route_prefix needed to speed up route matching
proc route_prefix*(path_or_pattern: string): string =
  let pattern = path_or_pattern.replace(re"^\^", "")
  assert pattern == "" or pattern.starts_with "/"
  re"^(/[a-z0-9_\-]+)".parse1(pattern).get("/")

test "route_prefix":
  assert "/a/b".route_prefix == "/a"
  assert "/a".route_prefix == "/a"
  assert "/a".route_prefix == "/a"
  assert "^/a(.+)".route_prefix == "/a"
  assert "".route_prefix == "/"
  assert "/".route_prefix == "/"


# parse_route --------------------------------------------------------------------------------------
type PreparedRoute* = object
  case is_pattern*: bool
  of true:
    prefix*:  string # route_prefix needed to speed up route matching
    pattern*: Regex
  of false:
    path*:    string

proc prepare_route*(pattern: string | Regex): PreparedRoute =
  when pattern is Regex:
    PreparedRoute(is_pattern: true, prefix: pattern.pattern.route_prefix, pattern: pattern)
  else:
    if ":" in pattern:
      PreparedRoute(is_pattern: true, prefix: pattern.route_prefix, pattern: pattern.route_pattern_to_re)
    else:
      let path = if pattern == "": "/" else: pattern
      PreparedRoute(is_pattern: false, path: path)


# parse_format, parse_mime -------------------------------------------------------------------------
let mimes = new_mimetypes()

proc parse_format*(query: Table[string, string], headers: Table[string, seq[string]]): Option[string] =
  if "format" in query: return query["format"].some
  let content_type = headers["Content-Type", headers["Accept", @[]]]
  if not content_type.is_blank:
    let ext = mimes.get_ext(content_type[0], "unknown")
    if ext != "unknown":
      return ext.some
  string.none

# "some/some.json" => "application/json"
proc parse_mime*(path: string): Option[string] =
  let ext = path.split_file.ext
  if not ext.is_empty:
    let m = mimes.get_mimetype(ext[1..^1], "unknown")
    if m != "unknown":
      return m.some
  string.none


# render_error_page --------------------------------------------------------------------------------
proc render_default_error_page*(message: string, error: ref Exception, show_error: bool): string =
  if show_error: fmt"""
<p>{message.escape_html}</p>
<pre>{message.escape_html}
{error.get_stack_trace.escape_html}</pre>
  """
  else:
    message.escape_html


# render_error_page --------------------------------------------------------------------------------
proc render_default_not_found_page*(message: string): string =
  message.escape_html


# asset_hash ---------------------------------------------------------------------------------------
proc asset_hash_slow*(path: string, assets_file_paths: seq[string], max_file_size: int): string =
  if ".." in path: throw "Invalid path"
  for prefix in assets_file_paths:
    let full_path = prefix / path
    if full_path.file_exists:
      let size = full_path.get_file_size
      if size > max_file_size:
        throw "Large files not supported"

      let content = read_file(full_path)
      return content.get_md5
  throw "File not found"

var asset_hash_cache: Table[string, string]
proc asset_hash*(path: string, assets_file_paths: seq[string], max_file_size: int): string =
  asset_hash_cache.mget(path, () => asset_hash_slow(path, assets_file_paths, max_file_size))


# handle_assets_slow -------------------------------------------------------------------------------
# It's slow, files in production should be served by NGinx
# It's slow in Nim because there's no back pressure, and large file would be loaded into
# memory https://github.com/dom96/jester/issues/181#issuecomment-812658617
proc handle_assets_slow*(
  path:              string,
  query:             Table[string, string],
  assets_path:       string,
  assets_file_paths: seq[string],
  max_file_size:     int,
  cache_assets:      bool
): Option[(int, string, seq[(string, string)])] =
  let empty_headers: seq[(string, string)] = @[]
  if path.starts_with(assets_path):
    if ".." in path:
      return (500, "Invalid path", empty_headers).some

    var path = path.replace(assets_path, "")
    for prefix in assets_file_paths:
      let full_path = prefix / path
      if full_path.file_exists:
        let size = full_path.get_file_size
        if size > max_file_size:
          return (500, "Error, large files not yet supported", empty_headers).some
        else:
          let mimetype = full_path.parse_mime.get("")
          var content = read_file(full_path)

          # Adding caching
          let headers = if cache_assets and ("hash" in query):
            { "Content-Type": mimetype, "Cache-Control": "public, max-age=31536000, immutable" }.to_seq
          else:
            { "Content-Type": mimetype }.to_seq

          return (200, content, headers).some
    log().with((time: Time.now, path: path)).error("{path} file not found")
    return (404, "Error, file not found", empty_headers).some
  return result