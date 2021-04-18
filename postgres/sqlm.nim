import basem, ./pg_convertersm

# SQL ----------------------------------------------------------------------------------------------
# Parameterised SQL
type SQL* = tuple[query: string, values: seq[string]]

# Replaces named parameters `:name` in SQL with questions `?`
proc sql*(query: string, args: tuple | object = (), validate_unused_keys = true): SQL =
  # Converting values to postgres
  var values: Table[string, Option[string]]
  for k, v in args.field_pairs:
    values[k] = v.to_postgres

  # Replacing SQL parameters
  var sql_keys: seq[string]; var ordered_values: seq[string]
  let replaced_sql = query.replace(re"(:[a-z0-9_]+)", proc (match: string): string =
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
  if validate_unused_keys:
    for k in values.keys:
      if k notin sql_keys: throw fmt"SQL param :{k} is not used"

  (replaced_sql, ordered_values)

test "sql":
  assert sql(
    "insert into users (name, age) values (:name, :age)",
    (name: "Jim", age: 33)
  ) == (
    "insert into users (name, age) values (?, ?)",
    @["Jim", "33"]
  )

  # `db_postgres` doesn't support null values, so they have to be set explicitly in SQL
  assert sql(
    "insert into users (name, age) values (:name, :age)",
    (name: "Jim", age: int.none)
  ) == (
    "insert into users (name, age) values (?, null)",
    @["Jim"]
  )

# Helpers ------------------------------------------------------------------------------------------
proc `$`*(query: SQL): string = query.query & " <- " & query.values.join(", ")

converter to_sqlp*(s: string): SQL = sql(s)