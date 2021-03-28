import basem, logm

import logging, mimetypes, strtabs

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
  re("^" & pattern_str & "$")

test "route_pattern_to_re":
  assert route_pattern_to_re("/users/:name/profile").parse_named("/users/alex/profile/") ==
    { "name": "alex" }.to_table


# parse_format -------------------------------------------------------------------------------------
let mime = new_mimetypes().to_shared_ptr

proc parse_format*(
  query: Table[string, string], headers: Table[string, seq[string]]
): Option[string] {.gcsafe.} =
  if "format" in query: return query["format"].some
  let content_type = headers["Content-Type", headers["Accept", @[]]]
  if not content_type.is_blank:
    let ext = mime[].get_ext(content_type[0], "unknown")
    if ext != "unknown":
      return ext.some
  string.none