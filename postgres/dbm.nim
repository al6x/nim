import basem, logm, jsonm
import ./pg_convertersm, ./sqlm
from osproc import exec_cmd_ex
from postgres import nil
from db_postgres import DbConn
import uri

export sqlm, DbConn

# Db -----------------------------------------------------------------------------------------------
type Db* = ref object
  name*:                   string
  url*:                    string
  encoding*:               string
  create_db_if_not_exist*: bool           # Create db if not exist
  id:                      string

proc log(db: Db): Log = Log.init("db", db.name)

# Connections --------------------------------------------------------------------------------------
# Using separate storage for connections, because they need to be mutable. The Db can't be mutable
# because it's needed to be passed around callbacks and sometimes Nim won't allow to pass mutable data
# in callbacks.
var connections:      Table[string, DbConn]
var before_callbacks: Table[string, seq[proc: void]]

# Db.init ------------------------------------------------------------------------------------------
proc init*(
  _:                       type[Db],
  name:                    string,
  url                    = "postgresql://postgres@localhost:5432",
  encoding               = "utf8",
  create_db_if_not_exist = true # Create db if not exist
): Db =
  let id = fmt"{url}/{name}/{encoding}/{create_db_if_not_exist}"
  # Connection will be establisehd lazily on demand, and reconnected after failure
  Db(name: name, url: url, encoding: encoding, create_db_if_not_exist: create_db_if_not_exist, id: id)


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
  if db.id notin connections: return
  let conn = connections[db.id]
  connections.del db.id
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
  if db.id notin connections:
    connections[db.id] = db.connect()

    if db.id in before_callbacks:
      db.log.info "applying before callbacks"
      for cb in before_callbacks[db.id]: cb()

  var success = false
  try:
    result = op(connections[db.id])
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
  var url = init_uri()
  parse_uri(db.url, url)
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

proc exec*(db: Db, query: string, log = true): void =
  if log: db.log.debug "exec"
  db.with_connection do (conn: auto) -> void:
    conn.exec_batch(query)

proc exec*(db: Db, query: SQL, log = true): void =
  if log: db.log.debug "exec"
  let pg_query = query.to_nim_postgres_sql
  db.with_connection do (conn: auto) -> void:
    db_postgres.exec(conn, db_postgres.sql(pg_query.query), pg_query.values)


# db.get ------------------------------------------------------------------------------------------
proc get*(db: Db, query: SQL, log = true): seq[seq[string]] =
  if log: db.log.debug "get"
  let pg_query = query.to_nim_postgres_sql
  db.with_connection do (conn: auto) -> auto:
    db_postgres.get_all_rows(conn, db_postgres.sql(pg_query.query), pg_query.values)

proc get*[T](db: Db, query: SQL, _: type[T], log = true): seq[T] =
  T.from_postgres db.get(query, log = log)


# db.get_one --------------------------------------------------------------------------------------
proc get_one*(db: Db, query: SQL | string, log = true): seq[string] =
  if log: db.log.debug "get_one"
  let rows = db.get(query, log = false)
  if rows.len > 1: throw fmt"expected single result but got {rows.len} rows"
  if rows.len < 1: throw fmt"expected single result but got {rows.len} rows"
  rows[0]

proc get_one*[T](db: Db, query: SQL | string, _: type[T], log = true): T =
  let row = db.get_one(query, log = false)
  when T is object | tuple:
    T.from_postgres row
  else:
    if row.len > 1: throw fmt"expected single column row, but got {row.len} columns"
    if row.len < 1: throw fmt"expected single column row, but got {row.len} columns"
    T.from_postgres row[0]


# db.before ----------------------------------------------------------------------------------------
# Callbacks to be executed before any query
proc before*(db: Db, cb: proc: void): void =
  var list = before_callbacks[db.id, @[]]
  list.add cb
  before_callbacks[db.id] = list

proc before*(db: Db, sql: string): void =
  db.before(() => db.exec(sql))


# --------------------------------------------------------------------------------------------------
# Test ---------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
if is_main_module:
  let db = Db.init("nim_test")
  # db.drop

  db.before """
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
    @["Jim", "30"]
  ]

  block: # SQL parameters
    assert db.get(
      sql"""select name, age from dbm_test_users where name = {"Jim"}"""
    ) == @[
      @["Jim", "30"]
    ]

  block: # Casting from Postges to array tuples
    let rows = db.get(
      sql"select name, age from dbm_test_users order by name", (string, int)
    )
    assert rows == @[("Jim", 30)]

  block: # Casting from Postges to objects and named tuples
    let rows = db.get(sql"select name, age from dbm_test_users order by name", tuple[name: string, age: int])
    assert rows == @[(name: "Jim", age: 30)]

  block: # Count
    assert db.get_one(sql"select count(*) from dbm_test_users where age = {30}", int) == 1

  # Cleaning
  db.exec("drop table if exists dbm_test_users")

  # block: # Auto reconnect, kill db and then restart it
  #   while true:
  #     try:
  #       echo db
  #         .get_raw("select name, age from dbm_test_users order by name")
  #         .to((string, int))
  #     except Exception as e:
  #       echo "error"
  #     sleep 1000