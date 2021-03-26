import logging, mimetypes
import ../basem, ../logm
# from ../http_serverm import Format

let logger = Log.init "HTTP"


# Ensuring HttpBeast is not used, as it's slow in threaded mode ------------------------------------
if not defined(useStdLib):
  logger.warn "define useStdLib, otherwise HttpBeast will be used and it's slow with ThreadPool"


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
  let pattern_str = route.replace(re"(:[a-z0-9]+)", proc (match: string): string =
    let name = match.replace(":", "")
    fmt"(?<{name}>[^/]+)"
  )
  re(pattern_str)

test "route_pattern_to_re":
  assert route_pattern_to_re("/users/:name/profile").parse_named("/users/alex/profile/") ==
    { "name": "alex" }.to_table


# parse_format -------------------------------------------------------------------------------------
let mime = new_mimetypes().to_shared_ptr

proc parse_format*(
  params: Table[string, string], headers: Table[string, seq[string]], default_format: string
): string {.gcsafe.} =
  if "format" in params: return params["format"]
  var content_type: seq[string] = @[]
  for key in @["Content-Type", "content-type", "Accept", "accept"]:
    if key in headers:
      content_type = headers[key]
      break
  if not content_type.is_blank:
    mime[].get_ext(content_type[0], "unknown")
  else:
    default_format