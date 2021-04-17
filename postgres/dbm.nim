import basem, logm
import ./convertersm
from osproc import exec_cmd_ex
from postgres import nil
import db_postgres
import uri

# Db -----------------------------------------------------------------------------------------------
type Db* = ref object
  name*:                   string
  url*:                    string
  encoding*:               string
  create_db_if_not_exist*: bool           # Create db if not exist
  id:                      string

proc log(db_name: string): Log  = Log.init("pg_" & db_name)
proc log(db: Db): Log  = log(db.name)

# Connections --------------------------------------------------------------------------------------
# Using separate storage for connections, because they need to be mutable. The Db can't be mutable
# because it's needed to be passed around callbacks and sometimes Nim won't allow to pass mutable data
# in callbacks.
var connections: Table[string, DbConn]


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
  db.log.with((user: user)).info "creating"
  let (output, code) = exec_cmd_ex fmt"createdb -U {user} {db.name}"
  if code != 0 and fmt"""database "{db.name}" already exists""" in output:
    throw "can't create database {user} {name}"


# db.drop ------------------------------------------------------------------------------------------
proc drop*(db: Db, user = "postgres"): void =
  # Using bash, don't know how to create db otherwise
  db.log.with((user: user)).info "dropping"
  let (output, code) = exec_cmd_ex fmt"dropdb -U {user} {db.name}"
  if code != 0 and fmt"""database "{db.name}" does not exist""" notin output:
    throw fmt"can't drop database {user} {db.name}"


# db.close -----------------------------------------------------------------------------------------
proc close*(db: Db): void =
  if db.id notin connections: return
  let conn = connections[db.id]
  connections.del db.id
  log(db.name).with((url: db.url)).info "closing {url}"
  conn.close()


# db.with_connection -------------------------------------------------------------------------------
#
# - Connect lazily on demand
# - Reconnect after error
# - Automatically create database if not exist
#
proc connect*(db: Db): DbConn

template with_connection*(db: Db, code: untyped): untyped =
  if db.id notin connections:
    connections[db.id] = db.connect()

  try:
    let connection {.inject.} = connections[db.id]
    code
  except Exception as e:
    # Reconnecting if connection is broken. There's no way to determine if error was caused by
    # broken connection or something else. So assuming that connection is broken and terminating it,
    # it will be reconnected next time automatically.
    try:
      db.close
    except Exception as e:
      log(db.name).with((url: db.url)).error("can't close connection", e)
    throw e

proc connect*(db: Db): DbConn =
  log(db.name).with((url: db.url)).info "connecting to {url}"
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
  if not connection.set_encoding(db.encoding): throw "can't set encoding"

  # Disabling logging https://forum.nim-lang.org/t/7801
  let stub: postgres.PQnoticeReceiver = proc (arg: pointer, res: postgres.PPGresult){.cdecl.} = discard
  discard postgres.pqsetNoticeReceiver(connection, stub, nil)
  connection


# db.exec ------------------------------------------------------------------------------------------
proc exec_fixed(connection: DbConn, sql: string) =
  # https://forum.nim-lang.org/t/7804
  var res = postgres.pqexec(connection, sql)
  if postgres.pqResultStatus(res) != postgres.PGRES_COMMAND_OK: dbError(connection)
  postgres.pqclear(res)

proc exec*(db: Db, sql: string): void =
  log(db.name).with((sql: sql)).debug "exec"
  db.with_connection:
    exec_fixed(connection, sql)

proc exec*(db: Db, sql: string, args: tuple | object): void =
  log(db.name).with((sql: sql)).debug "exec"
  let (sqls, values) = sqlp(sql, args)
  db.with_connection:
    connection.exec(db_postgres.sql(sqls), values)


# db.get_raw ---------------------------------------------------------------------------------------
proc get_raw*(db: Db, sql: string): seq[seq[string]] =
  log(db.name).with((sql: sql)).debug "get_raw"
  db.with_connection:
    connection.get_all_rows(db_postgres.sql(sql))

proc get_raw*(db: Db, sql: string, args: tuple | object): seq[seq[string]] =
  log(db.name).with((sql: sql)).debug "get_raw"
  let (sqls, values) = sqlp(sql, args)
  db.with_connection:
    connection.get_all_rows(db_postgres.sql(sqls), values)


# db.get -------------------------------------------------------------------------------------------
proc get*[T](db: Db, sql: string, _: type[T]): seq[T] =
  db.get_raw(sql).to(T)

proc get*[T](db: Db, sql: string, args: tuple | object, _: type[T]): seq[T] =
  db.get_raw(sql, args).to(T)


# # --------------------------------------------------------------------------------------------------
# # DbTable ------------------------------------------------------------------------------------------
# # --------------------------------------------------------------------------------------------------
# # type DbTable*[T] = ref object
# #   name*: string
# #   db*:   Db

# # proc `[]`*[T](table: DbTable, t: type[T], from_where: string): seq[T] =
# #   let sql = fmt"""select {t.column_names.join(", ")} {from_where}"""
# #   db.n_connection.get_all_rows(db_postgres.sql(sql)).to(T)

# # proc set*[T](db: Db, t: type[T], from_where: string): seq[T] =
# #   # log(db.name).with((sql: sql, `type`: $t)).debug "get {type}"
# #   let sql = fmt"""select {t.column_names.join(", ")} {from_where}"""
# #   db.n_connection.get_all_rows(db_postgres.sql(sql)).to(T)

# # proc insert*[T](db: Db, t: type[T], from_where: string): seq[T] =
# #   # log(db.name).with((sql: sql, `type`: $t)).debug "get {type}"
# #   let sql = fmt"""
# #     insert
# #     select {t.column_names.join(", ")} {from_where}
# #   """
# #   db.n_connection.get_all_rows(db_postgres.sql(sql)).to(T)

# # proc update*[T](db: Db, t: type[T], from_where: string): seq[T] =
# #   # log(db.name).with((sql: sql, `type`: $t)).debug "get {type}"
# #   let sql = fmt"""select {t.column_names.join(", ")} {from_where}"""
# #   db.n_connection.get_all_rows(db_postgres.sql(sql)).to(T)

# # #   INSERT INTO the_table (id, column_1, column_2)
# # # VALUES (1, 'A', 'X'), (2, 'B', 'Y'), (3, 'C', 'Z')
# # # ON CONFLICT (id) DO UPDATE
# # #   SET column_1 = excluded.column_1,
# # #       column_2 = excluded.column_2;


# --------------------------------------------------------------------------------------------------
# Test ---------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
if is_main_module:
  let db = Db.init("nim_test")
  # db.drop

  db.exec("""
    drop table if exists users;

    create table if not exists users(
      id         serial         not null,
      name       varchar(100)   not null,
      age        integer        not null,

      primary key (id)
    );
  """)

  # SQL values replacements
  db.exec(
    "insert into users (name, age) values (:name, :age)",
    (name: "Jim", age: 33)
  )
  assert db.get_raw("select name, age from users order by name") == @[
    @["Jim", "33"]
  ]

  block: # SQL parameters
    assert db.get_raw("""
      select name, age from users where name = :name""",
      (name: "Jim")
    ) == @[
      @["Jim", "33"]
    ]

  block: # Casting from Postges to array tuples
    let rows = db
      .get_raw("select name, age from users order by name")
      .to((string, int))
    assert rows == @[("Jim", 33)]

  block: # Casting from Postges to objects and named tuples
    let rows = db
      .get_raw("select name, age from users order by name")
      .to(tuple[name: string, age: int])
    assert rows == @[(name: "Jim", age: 33)]

  # block: # Auto reconnect, kill db and then restart it
  #   while true:
  #     try:
  #       echo db
  #         .get_raw("select name, age from users order by name")
  #         .to((string, int))
  #     except Exception as e:
  #       echo "error"
  #     sleep 1000