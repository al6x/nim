import basem, timem


# to_postgres --------------------------------------------------------------------------------------
# proc to_postgres*(v: Time):        Option[string] = some $v
# proc to_postgres*(v: string):      Option[string] = some v
# proc to_postgres*(v: int | float): Option[string] = some $v
# proc to_postgres*(v: bool):        Option[string] = some $v

# proc to_postgres*[T](v: Option[T]): Option[string]  =
#   if v.is_some: v.get.to_postgres else: string.none


# from_postgres ------------------------------------------------------------------------------------
proc from_postgres*(_: type[Time],   s: string): Time   = Time.init s
proc from_postgres*(_: type[string], s: string): string = s
proc from_postgres*(_: type[int],    s: string): int    = s.parse_int
proc from_postgres*(_: type[float],  s: string): float  = s.parse_float
proc from_postgres*(_: type[bool],   s: string): bool   =
  if s == "t": true elif s == "f": false else: throw fmt"unknown bool value '{s}'"

proc from_postgres*[T](_: type[Option[T]], s: string): Option[T] =
  # For string values it's impossible to distinguish null from empty string as the value for
  # both is the same - `""`
  if s == "": T.none else: T.from_postgres(s).some

proc from_postgres*[T](_: type[T], row: seq[string]): T =
  var i = 0
  when result is ref object:
    result = T()
    for _, v in result[].field_pairs:
      v = from_postgres(typeof v, row[i])
      i += 1
  else:
    for _, v in result.field_pairs:
      v = from_postgres(typeof v, row[i])
      i += 1

proc from_postgres*[T](_: type[T], rows: seq[seq[string]]): seq[T] =
  rows.map((row) => T.from_postgres(row))

test "from_postgres":
  let rows = @[
    @["Jim", "33"], @["Sarah", ""]
  ]

  # Converting raw rows to unnamed array-tuple
  assert (string, Option[int]).from_postgres(rows) == @[
    ("Jim", 33.some), ("Sarah", int.none)
  ]

  # Converting raw rows to named object or tuple
  assert (tuple[name: string, age: Option[int]]).from_postgres(rows) == @[
    (name: "Jim", age: 33.some), (name: "Sarah", age: int.none)
  ]

  # For optional string it's impossible to distinguish between null and blank string
  assert (string, Option[string]).from_postgres(@[@["", ""]]) == @[("", string.none)]