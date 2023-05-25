import options, strformat, strutils
import ./supportm

proc from_string*(_: type[string], s: string): string = s
proc from_string*(_: type[int],    s: string): int    = s.parse_int
proc from_string*(_: type[float],  s: string): float  = s.parse_float
proc from_string*(_: type[bool],   s: string): bool   =
  case s.to_lower
  of "yes", "true", "t":  true
  of "no",  "false", "f": false
  else: throw fmt"invalid bool '{v}'"

proc from_string*[T](_: type[Option[T]], s: string): Option[T] =
  if s == "": T.none else: T.from_string(s).some

# proc from_string*(_: type[Time],   s: string): Time   = Time.init s
# proc from_string*[T](_: type[T], row: seq[string]): T =
#   var i = 0
#   for _, v in result.field_pairs:
#     v = from_string(typeof v, row[i])
#     i += 1