import base/[basem, logm, jsonm, timem, rem]
import ./pg_convertersm, ./sqlm, ./utilm
from osproc import exec_cmd_ex
from postgres import nil
from db_postgres import DbConn

export sqlm, DbConn


# Db -----------------------------------------------------------------------------------------------
type Db* = ref object
  id*:                     string
  url*:                    PgUrl
  encoding*:               string
  create_db_if_not_exist*: bool
  plog:                    Log


# Db.init ------------------------------------------------------------------------------------------
proc init*(
  _:                       type[Db],
  id:                      string,
  name_or_url:             string,
  encoding               = "utf8",
  create_db_if_not_exist = true # Create db if not exist
): Db =
  # The connection will be establisehd later, lazily on demand, and reconnected after failure
  Db(id: id, url: PgUrl.parse(name_or_url), encoding: encoding,
    create_db_if_not_exist: create_db_if_not_exist, plog: Log.init(id))


# Logging ------------------------------------------------------------------------------------------
proc log*(db: Db): Log =
  db.plog

proc log*(db: Db, enabled: bool): Db =
  var db = db.copy
  db.plog = db.plog.log(enabled)
  db

proc log*(db: Db, msg: tuple): Db =
  var db = db.copy
  db.plog = db.plog.with(msg)
  db

proc sql_info*(sql: SQL, msg: string): tuple =
  let formatted_sql: string = sql.inline
  (sql: formatted_sql, info: msg & " '{sql}'")


# db.init ------------------------------------------------------------------------------------------
proc create*(db: Db): void =
  Log.init(db.id).info "create"
  let (output, code) = exec_cmd_ex fmt"createdb -U {db.url.user} {db.url.name}"
  if code != 0 and fmt"""database "{db.url.name}" already exists""" notin output:
    throw "can't create database {db.url.user} {db.url.name}"


# db.drop ------------------------------------------------------------------------------------------
proc drop*(db: Db): void =
  Log.init(db.id).info "drop"
  let (output, code) = exec_cmd_ex fmt"dropdb -U {db.url.user} {db.url.name}"
  if code != 0 and fmt"""database "{db.url.name}" does not exist""" notin output:
    throw fmt"can't drop database {db.url.user} {db.url.name}"


# Connections --------------------------------------------------------------------------------------
#
# - Connect lazily on demand
# - Reconnect after error
# - Automatically create database if not exist
#
# Using separate storage for connections, because they need to be mutable. The Db can't be mutable
# because it's needed to be passed around callbacks and sometimes Nim won't allow to pass mutable data
# in callbacks.
var connections:      Table[string, DbConn]
var before_callbacks: Table[string, seq[proc: void]]


# db.close -----------------------------------------------------------------------------------------
proc close*(db: Db): void =
  if db.id notin connections: return
  let conn = connections[db.id]
  connections.del db.id
  Log.init(db.id).info "close"
  db_postgres.close(conn)


proc connect(db: Db): DbConn

proc with_connection[R](db: Db, op: (DbConn) -> R): R =
  if db.id notin connections:
    connections[db.id] = db.connect()

    if db.id in before_callbacks:
      Log.init(db.id).info "applying before callbacks"
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
      except Exception as e: Log.init(db.id).warn("can't close connection", e)

proc with_connection(db: Db, op: (DbConn) -> void): void =
  discard db.with_connection(proc (conn: auto): auto =
    op(conn)
    true
  )

proc connect(db: Db): DbConn =
  Log.init(db.id).info "connect"

  proc connect(): auto =
    db_postgres.open(fmt"{db.url.host}:{db.url.port}", db.url.user, db.url.password, db.url.name)

  let connection = try:
    connect()
  except Exception as e:
    # Creating databse if doesn't exist and trying to reconnect
    if fmt"""database "{db.url.name}" does not exist""" in e.message and db.create_db_if_not_exist:
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

proc exec*(db: Db, query: SQL): void =
  db.log.message_if_empty sql_info(query, "exec")

  if ";" in query.query:
    if not query.values.is_empty: throw "multiple statements can't be used with parameters"
    db.with_connection do (conn: auto) -> void:
      conn.exec_batch(query.query)
  else:
    let pg_query = query.to_nim_postgres_sql
    db.with_connection do (conn: auto) -> void:
      db_postgres.exec(conn, db_postgres.sql(pg_query.query), pg_query.values)


# db.before ----------------------------------------------------------------------------------------
proc before(db: Db, cb: proc: void, prepend = false): void =
  # Callbacks to be executed before any query
  # Always adding callback even if it was already applied, as it could be re-applied after
  # reconnection
  let applied = db.id in connections
  var list = before_callbacks[db.id, @[]]
  before_callbacks[db.id] = if prepend:
    if applied: throw "can't prepend as callbacks were already applied"
    cb & list
  else: list & cb

  if applied:
    throw "too late, before callbacks already applied"
    # db.log.info "applying before callback"
    # cb()

proc before*(db: Db, query: SQL, prepend = false): void =
  let cb = proc =
    db.log.message_if_empty sql_info(query, "before")
    db.log(false).exec(query)
  db.before(cb, prepend)


# db.filter_raw, filter ----------------------------------------------------------------------------
proc filter_raw*(db: Db, query: SQL): seq[JsonNode] =
  db.log.message_if_empty sql_info(query, "filter")
  let pg_query = query.to_nim_postgres_sql
  db.log(false).with_connection do (conn: auto) -> auto:
    var rows: seq[JsonNode]
    var columns: db_postgres.DbColumns
    for row in db_postgres.instant_rows(conn, columns, db_postgres.sql(pg_query.query), pg_query.values):
      var jrow = newJObject()
      for i in 0..<columns.len:
        let name   = columns[i].name
        let kind   = columns[i].typ.kind
        let svalue = db_postgres.`[]`(row, i)
        jrow.add(name, from_postgres_to_json(kind, svalue))
      rows.add jrow
    rows


proc filter*[T](db: Db, query: SQL, _: type[T]): seq[T] =
  db.filter_raw(query).map((v) => v.postgres_to(T))


# db.fget_raw, get_raw -----------------------------------------------------------------------------
proc fget_raw*(db: Db, query: SQL): Option[JsonNode] =
  db.log.message_if_empty sql_info(query, "get")
  let rows = db.log(false).filter_raw(query)
  if rows.len > 1: throw fmt"expected single result but got {rows.len} rows"
  if rows.len < 1: return JsonNode.none
  rows[0].some


proc get_raw*(db: Db, query: SQL): JsonNode =
  db.fget_raw(query).get


# db.fget, get -------------------------------------------------------------------------------------
proc fget*[T](db: Db, query: SQL, _: type[T]): Option[T] =
  db.fget_raw(query).map((row) => row.postgres_to(T))

proc get*[T](db: Db, query: SQL, TT: type[T]): T =
  db.fget(query, TT).get


proc get*[T](db: Db, query: SQL, TT: type[T], default: T): T =
  db.fget(query, TT).get(default)


# db.fget_value, get_value -------------------------------------------------------------------------
proc fget_value*[T](db: Db, query: SQL, _: type[T]): Option[T] =
  db.fget_raw(query).map(proc (row: auto): T =
    if row.len > 1: throw fmt"expected single column row, but got {row.len} columns"
    for _, v in row.fields:
      return v.json_to(T)
    throw fmt"expected single column row, but got row without columns"
  )

proc get_value*[T](db: Db, query: SQL, TT: type[T]): T =
  db.fget_value(query, TT).get

proc get_value*[T](db: Db, query: SQL, TT: type[T], default: T): T =
  db.fget_value(query, TT).get(default)


# Test ---------------------------------------------------------------------------------------------
slow_test "db":
  # Will be connected lazily and reconnected in case of connection error
  let db = Db.init("db", "nim_test")
  # db.drop

  # Executing schema befor any other DB query, will be executed lazily before the first use
  db.log((info: "apply db schema")).before sql"""
    drop table if exists users;
    create table users(
      name varchar(100) not null,
      age  integer      not null
    );

    drop table if exists times;
    create table times(
      time timestamp not null
    );
  """

  block: # CRUD
    db.exec sql"""insert into users (name, age) values ({"Jim"}, {30})"""

    let users = db.filter(sql"select name, age from users order by name", tuple[name: string, age: int])
    assert users == @[(name: "Jim", age: 30)]

    assert db.get_value(sql"select count(*) from users where age = {30}", int) == 1


  block: # Timezone, should always use GMT
    let now = Time.now
    db.exec sql"insert into times (time) values ({now})"
    assert now == db.get_value(sql"select * from times", Time)

  db.close


  # block: # Auto reconnect, kill db and then restart it
  #   while true:
  #     try:
  #       echo db
  #         .get_raw("select name, age from dbm_test_users order by name")
  #         .to((string, int))
  #     except Exception as e:
  #       echo "error"
  #     sleep 1000