import logging
import basem, logm

let logger = Log.init "HTTP"


# Ensuring HttpBeast is not used, as it's slow in threaded mode ------------------------------------
if not defined(useStdLib):
  logger.warn "define useStdLib, otherwise HttpBeast will be used and it's slow with ThreadPool"


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