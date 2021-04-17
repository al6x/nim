import basem, timem

# to_postgres --------------------------------------------------------------------------------------
proc to_postgres*(v: Time): Option[string]          = some $v
proc to_postgres*(v: string): Option[string]        = some v
proc to_postgres*(v: int | float): Option[string]   = some $v
proc to_postgres*(v: bool): Option[string]          = some $v

proc to_postgres*[T](v: Option[T]): Option[string]  =
  if v.is_some: v.get.to_postgres else: string.none


# from_postgres ------------------------------------------------------------------------------------
proc from_postgres*(_: type[Time], s: string): Time      = Time.init s
proc from_postgres*(_: type[string], s: string): string  = s
proc from_postgres*(_: type[int], s: string): int        = s.parse_int
proc from_postgres*(_: type[float], s: string): float    = s.parse_float
proc from_postgres*(_: type[bool], s: string): bool      =
  if s == "t": true elif s == "f": false else: throw fmt"unknown bool value '{s}'"

proc from_postgres*[T](_: type[Option[T]], s: string): Option[T] =
  # For string values it's impossible to distinguish null from empty string as the value for
  # both is the same - `""`
  if s == "": T.none else: T.from_postgres(s).some


# Object serialisation and casting -----------------------------------------------------------------
proc from_postgres_row*[T](_: type[T], row: seq[string]): T =
  var i = 0
  for _, v in result.field_pairs:
    v = from_postgres(typeof v, row[i])
    i += 1

proc to*[T](rows: seq[seq[string]], _: type[T]): seq[T] =
  rows.map((row) => T.from_postgres_row(row))

proc fields*[T](_: type[T]): seq[string] =
  var t: T
  for k, _ in t.field_pairs:
    result.add k

test "postgres to":
  let rows_raw = @[
    @["Jim", "33"], @["Sarah", ""]
  ]

  # Converting raw rows to unnamed array-tuple
  assert rows_raw.to((string, Option[int])) == @[
    ("Jim", 33.some), ("Sarah", int.none)
  ]

  # Converting raw rows to named object or tuple
  assert rows_raw.to(tuple[name: string, age: Option[int]]) == @[
    (name: "Jim", age: 33.some), (name: "Sarah", age: int.none)
  ]

  # For optional string it's impossible to distinguish between null and blank string
  assert @[@["", ""]].to((string, Option[string])) == @[("", string.none)]


# SQLP ---------------------------------------------------------------------------------------------
# Parameterised SQL
type SQLP = (string, seq[string])

# Replaces named parameters `:name` in SQL with questions `?`
proc sqlp*(sql: string, args: tuple | object): SQLP =
  # Converting values to postgres
  var values: Table[string, Option[string]]
  for k, v in args.field_pairs:
    values[k] = v.to_postgres

  # Replacing SQL parameters
  var sql_keys: seq[string]; var ordered_values: seq[string]
  let replaced_sql = sql.replace(re"(:[a-z0-9_]+)", proc (match: string): string =
    let key = match.replace(":", "")
    sql_keys.add key
    let value = values.ensure(key, fmt"no SQL param :{key}")
    # Driver doesn't support nulls as parameters, setting NULL explicitly in the SQL
    if value.is_some:
      ordered_values.add values.ensure(key, fmt"no SQL param :{key}").get
      "?"
    else:
      "null"
  )
  # Ensuring there's no unused keys
  for k in values.keys:
    if k notin sql_keys: throw fmt"SQL param :{k} is not used"

  (replaced_sql, ordered_values)

test "sqlp":
  assert sqlp(
    "insert into users (name, age) values (:name, :age)",
    (name: "Jim", age: 33)
  ) == (
    "insert into users (name, age) values (?, ?)",
    @["Jim", "33"]
  )

  # `db_postgres` doesn't support null values, so they have to be set explicitly in SQL
  assert sqlp(
    "insert into users (name, age) values (:name, :age)",
    (name: "Jim", age: int.none)
  ) == (
    "insert into users (name, age) values (?, null)",
    @["Jim"]
  )


