import base/[basem, jsonm]
import std/[macros, parseutils, unicode]
import std/strutils except format

# SQL ----------------------------------------------------------------------------------------------
type SQL* = tuple[query: string, values: seq[JsonNode]] # Parameterised SQL

proc sql*(query: string, values: seq[JsonNode]): SQL = (query, values)

# Replaces named parameters `:name` in SQL with questions `?`
proc sql*(query: string, args: tuple | object, validate_unused_keys = true): SQL =
  # Converting values to postgres
  var values: Table[string, JsonNode]
  for k, v in args.field_pairs: values[k] = v.to_json
  # when compiles(args[]):
  #   for k, v in args[].field_pairs: values[k] = v.to_json
  # else:
  #   for k, v in args.field_pairs: values[k] = v.to_json

  # Replacing SQL parameters
  var sql_keys: seq[string]; var ordered_values: seq[JsonNode]
  let replaced_sql = query.replace(re"(:[a-z0-9_]+)", proc (match: string): string =
    let key = match.replace(":", "")
    sql_keys.add key
    let value = values.ensure(key, fmt"no SQL param :{key}")
    ordered_values.add value
    "?"
  )
  # Ensuring there's no unused keys
  if validate_unused_keys:
    for k in values.keys:
      if k notin sql_keys: throw fmt"SQL param :{k} is not used"

  (replaced_sql, ordered_values)

proc sql*(query: string, args: ref object, validate_unused_keys = true): SQL =
  sql(query, args[], validate_unused_keys)

test "sql":
  assert sql(
    "insert into users (name, age) values (:name, :age)",
    (name: "Jim", age: 33)
  ) == (
    "insert into users (name, age) values (?, ?)",
    @["Jim".to_json, 33.to_json]
  )

  # `db_postgres` doesn't support null values, so they have to be set explicitly in SQL
  assert sql(
    "insert into users (name, age) values (:name, :age)",
    (name: "Jim", age: int.none)
  ) == (
    "insert into users (name, age) values (?, ?)",
    @["Jim".to_json, int.none.to_json]
  )

# Helpers ------------------------------------------------------------------------------------------
proc `$`*(query: SQL): string = query.query & " <- " & query.values.map_it($it).join(", ")

# converter to_sqlp*(s: string): SQL = sql(s)


# sql macro ----------------------------------------------------------------------------------------
# Should be refactored
proc format_sql_value*[T](sql: var string, params: var seq[JsonNode], value: T, specifier: string) =
  if specifier != "": throw fmt"sql don't support non empty specifier, '{specifier}'"
  sql.add "?"
  params.add value.to_json

proc format_sql_value*[T](sql: var string, params: var seq[JsonNode], values: seq[T], specifier: string) =
  if specifier != "": throw fmt"sql don't support non empty specifier, '{specifier}'"
  sql.add "("
  for i, value in values:
    format_sql_value(sql, params, value, specifier)
    if i < (values.len - 1): sql.add ", "
  sql.add ")"

proc sql_format_mpl*(pattern: NimNode; openChar, closeChar: char): NimNode =
  if pattern.kind notin {nnkStrLit..nnkTripleStrLit}:
    error "string formatting (sql(), &) only works with string literals", pattern
  if openChar == ':' or closeChar == ':':
    error "openChar and closeChar must not be ':'"
  let f = pattern.strVal
  var i = 0
  let sql = genSym(nskVar, "sql")
  result = newNimNode(nnkStmtListExpr, lineInfoFrom = pattern)
  # XXX: https://github.com/nim-lang/Nim/issues/8405
  # When compiling with -d:useNimRtl, certain procs such as `count` from the strutils
  # module are not accessible at compile-time:
  let expectedGrowth = when defined(useNimRtl): 0 else: count(f, '{') * 10
  result.add newVarStmt(sql, newCall(bindSym"newStringOfCap",
                                     newLit(f.len + expectedGrowth)))

  let params = genSym(nskVar, "params")
  result.add quote do:
    var `params`: seq[JsonNode]

  var strlit = ""
  while i < f.len:
    if f[i] == openChar:
      inc i
      if f[i] == openChar:
        inc i
        strlit.add openChar
      else:
        if strlit.len > 0:
          result.add newCall(bindSym"add", sql, newLit(strlit))
          strlit = ""

        var subexpr = ""
        while i < f.len and f[i] != closeChar and f[i] != ':':
          if f[i] == '=':
            let start = i
            inc i
            i += f.skipWhitespace(i)
            if f[i] == closeChar or f[i] == ':':
              result.add newCall(bindSym"add", sql, newLit(subexpr & f[start ..< i]))
            else:
              subexpr.add f[start ..< i]
          else:
            subexpr.add f[i]
            inc i

        var x: NimNode
        try:
          x = parseExpr(subexpr)
        except ValueError:
          when declared(getCurrentExceptionMsg):
            let msg = getCurrentExceptionMsg()
            error("could not parse `" & subexpr & "`.\n" & msg, pattern)
          else:
            error("could not parse `" & subexpr & "`.\n", pattern)
        let formatSym = bindSym("format_sql_value", brOpen)
        var options = ""
        if f[i] == ':':
          inc i
          while i < f.len and f[i] != closeChar:
            options.add f[i]
            inc i
        if f[i] == closeChar:
          inc i
        else:
          doAssert false, "invalid format string: missing '}'"
        result.add newCall(formatSym, sql, params, x, newLit(options))
    elif f[i] == closeChar:
      if f[i+1] == closeChar:
        strlit.add closeChar
        inc i, 2
      else:
        doAssert false, "invalid format string: '}' instead of '}}'"
        inc i
    else:
      strlit.add f[i]
      inc i
  if strlit.len > 0:
    result.add newCall(bindSym"add", sql, newLit(strlit))

  # result.add newCall(bindSym"after_sql_format_impl", sql)
  result.add quote do:
    (`sql`, `params`)

macro sql*(code: untyped): SQL =
  sql_format_mpl(code, '{', '}')

# expand_macros:
#   discard sql"""insert into users (name, age) values ({"Jim"}, {33})"""

test "sql":
  assert sql"""insert into users (name, age) values ({"Jim"}, {33})""" == (
    "insert into users (name, age) values (?, ?)",
    @["Jim".to_json, 33.to_json]
  )

  # `db_postgres` doesn't support null values, so they have to be set explicitly in SQL
  assert sql"""insert into users (name, age) values ({"Jim"}, {int.none})""" == (
    "insert into users (name, age) values (?, ?)",
    @["Jim".to_json, int.none.to_json]
  )

  # Should expand list
  assert sql"""select count(*) from users where name in {@["Jim".some, "John".some, string.none]}""" == (
    "select count(*) from users where name in (?, ?, ?)",
    @["Jim".to_json, "John".to_json, string.none.to_json]
  )