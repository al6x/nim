import basem, logm, timem

import logging, mimetypes, os
import sharedtables, md5, hashes

proc log(): Log = Log.init "HTTP"


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


# Ensuring HttpBeast is not used, as it's slow in threaded mode ------------------------------------
if not defined(useStdLib):
  log().warn "define useStdLib, otherwise HttpBeast will be used and it's slow with ThreadPool"


# ignore_request -----------------------------------------------------------------------------------
proc ignore_request*(path: string): bool =
  path in @["/favicon.ico"]

# Disabling logging --------------------------------------------------------------------------------
type VoidLogger* = ref object of Logger

method log*(logger: VoidLogger, level: Level, args: varargs[string, `$`]) = discard

add_handler(VoidLogger())


# route_to_pattern ---------------------------------------------------------------------------------
# Rewrites `"/users/:name/profile/"` as `re"/users/(?<name>[^/]+)/profile"`
proc route_pattern_to_re*(route: string): Regex =
  var route = if route == "/": "" else: route
  let pattern_str = route.replace(re"(:[a-z0-9]+)", proc (match: string): string =
    let name = match.replace(":", "")
    fmt"(?<{name}>[^/]+)"
  )
  re("^" & pattern_str & "$")

test "route_pattern_to_re":
  assert route_pattern_to_re("/users/:name/profile").parse_named("/users/alex/profile") ==
    { "name": "alex" }.to_table


# parse_format, parse_mime -------------------------------------------------------------------------
let mimes = new_mimetypes().to_shared_ptr

proc parse_format*(
  query: Table[string, string], headers: Table[string, seq[string]]
): Option[string] {.gcsafe.} =
  if "format" in query: return query["format"].some
  let content_type = headers["Content-Type", headers["Accept", @[]]]
  if not content_type.is_blank:
    let ext = mimes[].get_ext(content_type[0], "unknown")
    if ext != "unknown":
      return ext.some
  string.none

proc parse_mime*(
  path: string
): Option[string] {.gcsafe.} =
  let ext = path.split_file.ext
  if not ext.is_empty:
    let m = mimes[].get_mimetype(ext[1..^1], "unknown")
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

var filehashes: SharedTable[string, string]
filehashes.init

proc asset_hash*(path: string, assets_file_paths: seq[string], max_file_size: int): string =
  # Using path_hash and hash as int because SharedTable dosn't support strings
  let path_hash = path.hash.int
  var content_hash: string
  filehashes.with_key(path, proc (key: string, val: var string, pair_exists: var bool) =
    if not pair_exists:
      val = asset_hash_slow(path, assets_file_paths, max_file_size)
    content_hash = val
  )
  content_hash


# handle_assets_slow -------------------------------------------------------------------------------
# TODO 2, it's slow, files in production should be served by NGinx
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