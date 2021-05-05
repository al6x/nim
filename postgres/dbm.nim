import basem, logm, jsonm
import ./pg_convertersm, ./sqlm
from osproc import exec_cmd_ex
from postgres import nil
from db_postgres import DbConn
from uri import nil

export sqlm, DbConn

# Db -----------------------------------------------------------------------------------------------
type Db* = ref object
  name*:                   string
  url*:                    string
  encoding*:               string
  create_db_if_not_exist*: bool           # Create db if not exist

proc hash*(db: Db): Hash = db.autohash

proc log(db: Db): Log = Log.init("db", db.name)

# Connections --------------------------------------------------------------------------------------
# Using separate storage for connections, because they need to be mutable. The Db can't be mutable
# because it's needed to be passed around callbacks and sometimes Nim won't allow to pass mutable data
# in callbacks.
var connections:      Table[Db, DbConn]
var before_callbacks: Table[Db, seq[proc: void]]


# Db.init ------------------------------------------------------------------------------------------
proc init*(
  _:                       type[Db],
  name:                    string,
  url                    = "postgresql://postgres@localhost:5432",
  encoding               = "utf8",
  create_db_if_not_exist = true # Create db if not exist
): Db =
  # Connection will be establisehd lazily on demand, and reconnected after failure
  Db(name: name, url: url, encoding: encoding, create_db_if_not_exist: create_db_if_not_exist)


# db.create ----------------------------------------------------------------------------------------
proc create*(db: Db, user = "postgres"): void =
  # Using bash, don't know how to create db otherwise
  db.log.info "create"
  let (output, code) = exec_cmd_ex fmt"createdb -U {user} {db.name}"
  if code != 0 and fmt"""database "{db.name}" already exists""" in output:
    throw "can't create database {user} {name}"


# db.drop ------------------------------------------------------------------------------------------
proc drop*(db: Db, user = "postgres"): void =
  # Using bash, don't know how to db db otherwise
  db.log.info "drop"
  let (output, code) = exec_cmd_ex fmt"dropdb -U {user} {db.name}"
  if code != 0 and fmt"""database "{db.name}" does not exist""" notin output:
    throw fmt"can't drop database {user} {db.name}"


# db.close -----------------------------------------------------------------------------------------
proc close*(db: Db): void =
  if db notin connections: return
  let conn = connections[db]
  connections.del db
  db.log.info "close"
  db_postgres.close(conn)


# db.with_connection -------------------------------------------------------------------------------
#
# - Connect lazily on demand
# - Reconnect after error
# - Automatically create database if not exist
#
proc connect(db: Db): DbConn

proc with_connection*[R](db: Db, op: (DbConn) -> R): R =
  if db notin connections:
    connections[db] = db.connect()

    if db in before_callbacks:
      db.log.info "applying before callbacks"
      for cb in before_callbacks[db]: cb()

  var success = false
  try:
    result = op(connections[db])
    success = true
  finally:
    if not success:
      # Reconnecting if connection is broken. There's no way to determine if error was caused by
      # broken connection or something else. So assuming that connection is broken and terminating it,
      # it will be reconnected next time automatically.
      try:                   db.close
      except Exception as e: db.log.warn("can't close connection", e)

proc with_connection*(db: Db, op: (DbConn) -> void): void =
  discard db.with_connection(proc (conn: auto): auto =
    op(conn)
    true
  )

proc connect(db: Db): DbConn =
  db.log.info "connect"
  var url = uri.init_uri()
  uri.parse_uri(db.url, url)
  assert url.scheme == "postgresql"

  proc connect(): auto =
    db_postgres.open(fmt"{url.hostname}:{url.port}", url.username, url.password, db.name)

  let connection = try:
    connect()
  except Exception as e:
    # Creating databse if doesn't exist and trying to reconnect
    if fmt"""database "{db.name}" does not exist""" in e.message and db.create_db_if_not_exist:
      db.create
      connect()
    else:
      throw e

  # Setting encoding
  if not db_postgres.set_encoding(connection, db.encoding): throw "can't set encoding"

  # Disabling logging https://forum.nim-lang.org/t/7801
  let stub: postgres.PQnoticeReceiver = proc (arg: pointer, res: postgres.PPGresult){.cdecl.} = discard
  discard postgres.pqsetNoticeReceiver(connection, stub, nil)
  connection


# to_nim_postgres_sql ------------------------------------------------------------------------------
type NimPostgresSQL* = tuple[query: string, values: seq[string]] # Parameterised SQL

proc to_nim_postgres_sql*(sql: SQL): NimPostgresSQL =
  # Nim driver for PostgreSQL requires special format because:
  # - it doesn't support null in SQL params
  # - it doesn't support typed params, all params should be strings
  var i = 0
  var values: seq[string]
  let query: string = sql.query.replace(re"\?", proc (v: string): string =
    let v = sql.values[i]
    i += 1
    case v.kind:
    of JNull:
      "null"
    of JString:
      values.add v.get_str
      "?"
    else:
      values.add $v
      "?"
  )
  if i != sql.values.len: throw fmt"number parameters in SQL doesn't match, {sql}"
  (query: query, values: values)


# db.exec ------------------------------------------------------------------------------------------
proc exec_batch(connection: DbConn, query: string) =
  # https://forum.nim-lang.org/t/7804
  var res = postgres.pqexec(connection, query)
  if postgres.pqResultStatus(res) != postgres.PGRES_COMMAND_OK: db_postgres.dbError(connection)
  postgres.pqclear(res)

proc exec*(db: Db, query: SQL, log = true): void =
  if log: db.log.debug "exec"
  if ";" in query.query:
    if not query.values.is_empty: throw "multiple statements can't be used with parameters"
    db.with_connection do (conn: auto) -> void:
      conn.exec_batch(query.query)
  else:
    let pg_query = query.to_nim_postgres_sql
    db.with_connection do (conn: auto) -> void:
      db_postgres.exec(conn, db_postgres.sql(pg_query.query), pg_query.values)


# db.get ------------------------------------------------------------------------------------------
proc get_raw*(db: Db, query: SQL, log = true): seq[seq[string]] =
  if log: db.log.debug "get"
  let pg_query = query.to_nim_postgres_sql
  db.with_connection do (conn: auto) -> auto:
    db_postgres.get_all_rows(conn, db_postgres.sql(pg_query.query), pg_query.values)

proc get*[T](db: Db, query: SQL, _: type[T], log = true): seq[T] =
  T.from_postgres db.get_raw(query, log = log)


# db.get_one --------------------------------------------------------------------------------------
proc get_one_raw*(db: Db, query: SQL, log = true): seq[string] =
  if log: db.log.debug "get_one"
  let rows = db.get_raw(query, log = false)
  if rows.len > 1: throw fmt"expected single result but got {rows.len} rows"
  if rows.len < 1: throw fmt"expected single result but got {rows.len} rows"
  rows[0]

proc get_one*[T](db: Db, query: SQL, _: type[T], log = true): T =
  let row = db.get_one_raw(query, log = false)
  when T is object | tuple:
    T.from_postgres row
  else:
    if row.len > 1: throw fmt"expected single column row, but got {row.len} columns"
    if row.len < 1: throw fmt"expected single column row, but got {row.len} columns"
    T.from_postgres row[0]


# db.before ----------------------------------------------------------------------------------------
# Callbacks to be executed before any query
proc before*(db: Db, cb: proc: void): void =
  var list = before_callbacks[db, @[]]
  list.add cb
  before_callbacks[db] = list

proc before*(db: Db, sql: SQL): void =
  db.before(() => db.exec(sql))


# --------------------------------------------------------------------------------------------------
# Test ---------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
if is_main_module:
  # No need to manage connections, it will be connected lazily and
  # reconnected in case of connection error
  let db = Db.init("nim_test")
  # db.drop

  # Executing schema befor any other DB query, will be executed lazily before the first use
  db.before sql"""
    drop table if exists dbm_test_users;

    create table dbm_test_users(
      name varchar(100) not null,
      age  integer      not null
    );
  """

  # SQL with `:named` parameters instead of `?`
  db.exec(sql(
    "insert into dbm_test_users (name, age) values (:name, :age)",
    (name: "Jim", age: 30)
  ))
  assert db.get(
    sql"select name, age from dbm_test_users order by name", (string, int)
  ) == @[
    ("Jim", 30)
  ]

  # SQL parameters
  assert db.get(
    sql"""select name, age from dbm_test_users where name = {"Jim"}""", (string, int)
  ) == @[
    ("Jim", 30)
  ]

  # Casting from Postges to objects and named tuples
  assert db.get(
    sql"select name, age from dbm_test_users order by name", tuple[name: string, age: int]
  ) == @[
    (name: "Jim", age: 30)
  ]

  # Count
  assert db.get_one(
    sql"select count(*) from dbm_test_users where age = {30}", int
  ) == 1

  # Cleaning
  db.exec sql"drop table if exists dbm_test_users"

  # block: # Auto reconnect, kill db and then restart it
  #   while true:
  #     try:
  #       echo db
  #         .get_raw("select name, age from dbm_test_users order by name")
  #         .to((string, int))
  #     except Exception as e:
  #       echo "error"
  #     sleep 1000