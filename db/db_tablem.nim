import base/[basem, logm, parsersm, jsonm]
import ./sqlm, ./dbm

export sqlm, dbm

# DbTable ------------------------------------------------------------------------------------------
type DbTable*[T] = object
  db*:      Db
  name*:    string
  ids*:     seq[string]
  auto_id*: bool


# db.table -----------------------------------------------------------------------------------------
proc table*[T](
  db:       Db,
  _:        type[T],
  name:     string,
  ids     = @["id"],
  auto_id = false
): DbTable[T] =
  DbTable[T](db: db, name: name, ids: ids, auto_id: auto_id)


# Logging ------------------------------------------------------------------------------------------
proc default_log[T](table: DbTable[T], msg: string): LogFn =
  return proc (log: Log) = log.with(table.name).info msg

proc default_where_log[T](table: DbTable[T], msg: string, sql: SQL): LogFn =
  return proc (log: Log) = log.with((id: table.name, where: sql.inline)).info msg & " '{where}'"

# o.column_names -----------------------------------------------------------------------------------
proc column_names*[T](o: T): seq[string] =
  when compiles(o.custom_column_names): o.custom_column_names
  else:                                 o.field_names


# table.create -------------------------------------------------------------------------------------
proc create*[T](table: DbTable[T], o: T): T =
  if table.ids.is_empty:
    let query = block:
      let column_names = o.column_names
      let names = " " & column_names.join(",  ")
      let values = column_names.map((n) => fmt":{n}").join(", ")
      fmt"""
        insert into {table.name}
          ({names})
        values
          ({values})
      """.dedent

    table.db.exec(sql(query, o, false), table.default_log("create"))
    o
  else:
    let query = block:
      let column_names = if table.auto_id: o.column_names.filter((n) => n notin table.ids)
      else:                                o.column_names
      let names = " " & column_names.join(",  ")
      let values = column_names.map((n) => fmt":{n}").join(", ")
      let ids = table.ids.join(", ")
      fmt"""
        insert into {table.name}
          ({names})
        values
          ({values})
        returning {ids}
      """.dedent

    let updated_ids = table.db.get_raw(sql(query, o, false), table.default_log("create"))
    var o = o
    o.update_from updated_ids
    o

proc create*[T](table: DbTable[T], o: var T): void =
  let io = o
  o = table.create(io)

# table.update -------------------------------------------------------------------------------------
proc update*[T](table: DbTable[T], o: T): void =
  if table.ids.is_empty: throw "can't update object without id"
  let query = block:
    let setters = o.column_names.filter((n) => n notin table.ids).map((n) => fmt"{n} = :{n}").join(", ")
    let where = table.ids.map((n) => fmt"{n} = :{n}").join(" and ")
    fmt"""
      update {table.name}
      set
        {setters}
      where {where}
    """.dedent
  table.db.log(false).exec(sql(query, o), table.default_log("update"))


# table.save ---------------------------------------------------------------------------------------
proc save*[T](table: DbTable[T], o: T): T =
  if table.ids.is_empty: throw "can't save object without id"
  let query = block:
    let column_names =
      if table.auto_id: o.column_names.filter((n) => n notin table.ids)
      else:             o.column_names
    let ids = table.ids.join(", ")
    let insert_columns = " " & column_names.join(",  ")
    let insert_values  = column_names.map((n) => fmt":{n}").join(", ")
    let setters = column_names.map((n) => fmt"{n} = excluded.{n}").join(", ")
    fmt"""
      insert into {table.name}
        ({insert_columns})
      values
        ({insert_values})
      on conflict ({ids}) do update
      set
        {setters}
      returning {ids}
    """.dedent

  let updated_ids = table.db.get_raw(sql(query, o, false), table.default_log("save"))
  var o = o
  o.update_from updated_ids
  o

proc save*[T](table: DbTable[T], o: var T): void =
  let io = o
  o = table.save(io)

# build_where --------------------------------------------------------------------------------------
proc build_where[T, W](_: type[T], where: W, ids: seq[string]): SQL =
  when where is T:
    if ids.is_empty:
      let conditions = where.field_names.map((name) => fmt"{name} = :{name}").join(" and ")
      sql(conditions, where)
    else:
      sql(ids.map((n) => fmt"{n} = :{n}").join(" and "), where, validate_unused_keys = false)
  elif where is SQL:
    where
  elif where is tuple:
    let conditions = where.field_names.map((name) => fmt"{name} = :{name}").join(" and ")
    sql(conditions, where)
  elif where is string or where is int:
    sql "id = {where}"
  else:
    throw fmt"unsupported where clause {where}"

test "build_query":
  type NIUser = tuple[name: string, id: int]

  assert NIUser.build_where(sql"id = {1}", @[]) == sql("id = :id", (id: 1))

  assert NIUser.build_where((id: 1), @[]) == sql("id = :id", (id: 1))

  assert NIUser.build_where(1, @[]) == sql("id = :id", (id: 1))

  assert NIUser.build_where((name: "Jim", id: 1), @[])     ==  sql"""id = {1} and name = {"Jim"}"""
  assert NIUser.build_where((name: "Jim", id: 1), @["id"]) ==  sql"id = {1}"


# table.filter -------------------------------------------------------------------------------------
proc filter[T, W](table: DbTable[T], where: W, limit = 0, log: LogFn = nil): seq[T] =
  let where_sql = T.build_where(where, table.ids)
  let where_key = if where_sql.query == "": "" else: " where "
  let limit_s = if limit > 0: fmt" limit {limit}" else: ""
  var query = fmt"select * from {table.name}{where_key}{where_sql.query}{limit_s}"
  let log = log.if_nil(table.default_where_log("filter", where_sql))
  table.db.filter((query, where_sql.values), T, log = log)


# table.fget ---------------------------------------------------------------------------------------
proc fget*[T, W](table: DbTable[T], where: W): Option[T] =
  let where_sql = T.build_where(where, table.ids)
  let found = table.filter(where_sql, 0, log = table.default_where_log("get", where_sql))
  if found.len > 1: throw fmt"expected one but found {found.len} objects"
  if found.len > 0: found[0].some else: T.none


# table.del ----------------------------------------------------------------------------------------
proc del*[T, W](table: DbTable[T], where: W): void =
  let where_sql = T.build_where(where, table.ids)
  if where_sql.query == "": throw "use del_all to delete whole table"
  let full_sql = (fmt"delete from {table.name} where {where_sql.query}", where_sql.values)
  table.db.exec(full_sql, log = table.default_where_log("del", where_sql))


# table.del_all ------------------------------------------------------------------------------------
proc del_all*[T](table: DbTable[T]): seq[T] =
  var query = fmt"delete from {table.name}"
  table.db.exec(sql(query), log = table.default_log("del_all"))


# table.count --------------------------------------------------------------------------------------
proc count*[T, W](table: DbTable[T], where: W = sql""): int =
  let where_sql = T.build_where(where, table.ids)
  let where_key = if where_sql.query == "": "" else: " where "
  var query = fmt"select count(*) from {table.name}{where_key}{where_sql.query}"
  table.db.get_value((query, where_sql.values), int, log = table.default_where_log("count", where_sql))


# table.contains -----------------------------------------------------------------------------------
proc contains*[T, W](table: DbTable[T], where: W): bool =
  table.count(where) > 0


# [] -----------------------------------------------------------------------------------------------
proc `[]`*[T, W](table: DbTable[T], where: W): T =
  table.fget(where).get

proc `[]`*[T, W](table: DbTable[T], where: W, default: T): T =
  table.fget(where).get(default)


# Test ---------------------------------------------------------------------------------------------
slow_test "DbTable":
  let db = Db.init("db", "nim_test")

  db.before sql"""
    drop table if exists users;
    create table users(
      id   integer      not null,
      name varchar(100) not null,
      age  integer      not null,

      primary key (id)
    );
  """, "creating schema"

  # Defining User Model
  type User = object
    id:   int
    name: string
    age:  int

  let users = db.table(User, "users")

  # Saving
  var jim = User(id: 1, name: "Jim", age: 30)
  users.create jim # jim.id going to be updated by database

  users.save jim

  jim.age = 31
  users.save jim

  # refresh
  assert users[jim] == jim

  # filter
  assert users.filter(sql"age = {31}") == @[jim]
  assert users.filter((age: 31))       == @[jim]
  assert users.filter(1)               == @[jim]

  # []
  assert users[sql"age = {31}"] == jim
  assert users[(age: 31)]       == jim
  assert users[1]               == jim

  # count, has
  assert users.count((age: 31)) == 1
  assert (age: 31) in users

  # del
  users.del (id: -1) # just checking if it's compile
  users.del jim
  assert users.count == 0

  db.close