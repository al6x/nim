import basem, logm, jsonm, setm, hashes, httpm, urlm
import ./pg_convertersm, ./sqlm

export sqlm

# Cdb ----------------------------------------------------------------------------------------------
type Cdb* = ref object
  name*:      string
  url*:       string
  parsed_url: Url

proc log(db: Cdb): Log = Log.init("db", db.name)

proc hash*(db: Cdb): Hash = db.autohash


# Cdb.init ------------------------------------------------------------------------------------------
proc init*(
  _:   type[Cdb],
  name = "cdb",
  url  = "http://localhost:80?user=user&password=password"
): Cdb =
  Cdb(name: name, url: url, parsed_url: Url.parse(url))


# Before Callbacks ---------------------------------------------------------------------------------
var before_callbacks_applied: HashSet[Cdb]
var before_callbacks: Table[Cdb, seq[proc: void]]
# Callbacks stored separately from `db` because the db can't be mutable as it's needed to be passed around
# callbacks and sometimes Nim won't allow to pass mutable data in callbacks.

proc apply_callbacks_if_not_applied(db: Cdb) =
  if db in before_callbacks_applied: return
  before_callbacks_applied.add db
  db.log.info "applying before callbacks"
  for cb in before_callbacks[db]: cb()


# db.cable_exec ------------------------------------------------------------------------------------
type RawRows = ref object
  rows: seq[JsonNode]

proc to_raw_rows(raw: JsonNode): RawRows =
  result = RawRows()
  for raw_row in raw:
    assert raw_row.kind == JObject
    result.rows.add raw_row

proc cable_exec(db: Cdb, query: SQL): Fallible[RawRows] =
  let sql_query =
    when query is string: sql(query, ())
    else:                 query
  let url = $(db.parsed_url & "/db/exec")
  let raw = http_post_raw(url, sql_query.to_json).parse_json
  if raw.kind == JObject and "is_error" in raw:
    if raw["is_error"].get_bool: RawRows.error(raw["message"].get_str)
    else:                        raw["value"].to_raw_rows.success
  else:
    raw.to_raw_rows.success


# db.exec ------------------------------------------------------------------------------------------
proc exec*(db: Cdb, query: SQL, log = true): void =
  db.apply_callbacks_if_not_applied
  if log: db.log.debug "exec"
  let r = db.cable_exec(query).get
  if r.rows.len > 0: throw fmt"should return no rows, {query}"


# db.get -------------------------------------------------------------------------------------------
proc get*(db: Cdb, query: SQL, log = true): seq[JsonNode] =
  db.apply_callbacks_if_not_applied
  if log: db.log.debug "get"
  db.cable_exec(query).get.rows

proc get*[T](db: Cdb, query: SQL, _: type[T], log = true): seq[T] =
  db.get(query, log = log).map((raw_row) => raw_row.to(T))


# db.get_one ---------------------------------------------------------------------------------------
proc get_one*(db: Cdb, query: SQL, log = true): JsonNode =
  if log: db.log.debug "get_one"
  let rows = db.get(query, log = false)
  if rows.len > 1: throw fmt"expected single result but got {rows.len} rows"
  if rows.len < 1: throw fmt"expected single result but got {rows.len} rows"
  rows[0]

proc get_one*[T](db: Cdb, query: SQL, _: type[T], log = true): T =
  let row = db.get_one(query, log = false)
  when T is object | tuple:
    row.to(T)
  else:
    if row.fields.len > 1: throw fmt"expected single column row, but got {row.len} columns"
    if row.fields.len < 1: throw fmt"expected single column row, but got {row.len} columns"
    for _, v in row.fields:
      return v.to(T)


# db.before ----------------------------------------------------------------------------------------
# Callbacks to be executed before any query
proc before*(db: Cdb, cb: proc: void): void =
  var list = before_callbacks[db, @[]]
  list.add cb
  before_callbacks[db] = list

proc before*(db: Cdb, sql: SQL): void =
  db.before(() => db.exec(sql))


# --------------------------------------------------------------------------------------------------
# Test ---------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
if is_main_module:
  let db = Cdb.init("nim_test")

  db.before sql"""
    drop table if exists dbm_test_users;

    create table dbm_test_users(
      name varchar(100) not null,
      age  integer      not null
    );
  """

  # SQL values replacements
  db.exec(sql(
    "insert into dbm_test_users (name, age) values (:name, :age)",
    (name: "Jim", age: 30)
  ))
  assert db.get(
    sql"select name, age from dbm_test_users order by name"
  ) == @[
    %(name: "Jim", age: 30)
  ]

  # SQL parameters
  assert db.get(
    sql"""select name, age from dbm_test_users where name = {"Jim"}"""
  ) == @[
    %(name: "Jim", age: 30)
  ]

  # Casting from Postges to array tuples is not supported
  # assert db.get(
  #   sql"select name, age from dbm_test_users order by name", tuple[name: string, age: int]
  # ) == @[
  #   (name: "Jim", age: 30)
  # ]

  # Casting from Postges to objects and named tuples
  assert db.get(
    sql"select name, age from dbm_test_users order by name", tuple[name: string, age: int]
  ) == @[
    (name: "Jim", age: 30)
  ]

  # Count
  assert db.get_one(sql"select count(*) from dbm_test_users where age = {30}", int) == 1

  # Cleaning
  db.exec sql"drop table if exists dbm_test_users"