import basem, ./pg_convertersm
import std/[macros, parseutils, unicode]
import std/strutils except format


# SQL ----------------------------------------------------------------------------------------------
# Parameterised SQL
type SQL* = tuple[query: string, values: seq[string]]

# Replaces named parameters `:name` in SQL with questions `?`
proc sql*(query: string, args: tuple | object, validate_unused_keys = true): SQL =
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

# converter to_sqlp*(s: string): SQL = sql(s)


# sql macro ----------------------------------------------------------------------------------------
# Should be refactored
proc format_sql_value*[T](result: var string; value: T; specifier: string) =
  assert specifier == "", fmt"sql don't support non empty specifier, '{specifier}'"
  let pv = value.to_postgres
  result.add if pv.is_some:
    "_sql_value_begin22_" & pv.get & "_sql_value_end22_"
  else:
    "_sql_value_null22_"

proc after_sql_format_impl*(s: string): SQL =
  var values: seq[string]
  let value_re = re"_sql_value_begin22_(.+?)_sql_value_end22_|_sql_value_null22_"
  let query: string = s.replace(value_re, proc (v: string): string =
    if v == "_sql_value_null22_":
      "null"
    else:
      values.add(v.replace(re"_sql_value_begin22_|_sql_value_end22_", ""))
      "?"
  )
  (query: query, values: values)

proc sql_format_mpl*(pattern: NimNode; openChar, closeChar: char): NimNode =
  if pattern.kind notin {nnkStrLit..nnkTripleStrLit}:
    error "string formatting (sql(), &) only works with string literals", pattern
  if openChar == ':' or closeChar == ':':
    error "openChar and closeChar must not be ':'"
  let f = pattern.strVal
  var i = 0
  let res = genSym(nskVar, "fmtRes")
  result = newNimNode(nnkStmtListExpr, lineInfoFrom = pattern)
  # XXX: https://github.com/nim-lang/Nim/issues/8405
  # When compiling with -d:useNimRtl, certain procs such as `count` from the strutils
  # module are not accessible at compile-time:
  let expectedGrowth = when defined(useNimRtl): 0 else: count(f, '{') * 10
  result.add newVarStmt(res, newCall(bindSym"newStringOfCap",
                                     newLit(f.len + expectedGrowth)))
  var strlit = ""
  while i < f.len:
    if f[i] == openChar:
      inc i
      if f[i] == openChar:
        inc i
        strlit.add openChar
      else:
        if strlit.len > 0:
          result.add newCall(bindSym"add", res, newLit(strlit))
          strlit = ""

        var subexpr = ""
        while i < f.len and f[i] != closeChar and f[i] != ':':
          if f[i] == '=':
            let start = i
            inc i
            i += f.skipWhitespace(i)
            if f[i] == closeChar or f[i] == ':':
              result.add newCall(bindSym"add", res, newLit(subexpr & f[start ..< i]))
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
        result.add newCall(formatSym, res, x, newLit(options))
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
    result.add newCall(bindSym"add", res, newLit(strlit))


  # Change
  result.add newCall(bindSym"after_sql_format_impl", res)
  # result.add res


  when defined(debugFmtDsl):
    echo repr result

macro sql*(code: untyped): SQL =
  sql_format_mpl(code, '{', '}')

test "sql":
  assert sql(
    """insert into users (name, age) values ({"Jim"}, {33})""",
  ) == (
    "insert into users (name, age) values (?, ?)",
    @["Jim", "33"]
  )

  # `db_postgres` doesn't support null values, so they have to be set explicitly in SQL
  assert sql(
    """insert into users (name, age) values ({"Jim"}, {int.none})""",
  ) == (
    "insert into users (name, age) values (?, null)",
    @["Jim"]
  )