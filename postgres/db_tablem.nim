import basem, logm
import ./dbm, ./convertersm

# DbTable ------------------------------------------------------------------------------------------
type DbTable*[T] = ref object
  db*:   Db
  name*: string

proc log(table: DbTable): Log = Log.init("db", table.db.name)


# db.table -----------------------------------------------------------------------------------------
proc table*[T](db: Db, _: type[T], name: string): DbTable[T] =
  DbTable[T](db: db, name: name)


# table.create -------------------------------------------------------------------------------------
var sql_cache: Table[(string, string), string]

proc create*[T](table: DbTable, o: T): void =
  table.log.with((table: table.name, id: o.id)).info "{table}.create id={id}"
  let generate_sql = proc (): string =
    let column_names = " " & T.fields.join(",  ")
    let named_values = T.fields.map((n) => fmt":{n}").join(", ")
    fmt"""
      insert into {table.name}
        ({column_names})
      values
        ({named_values})
    """.dedent
  let sql = sql_cache.mget(("create", $o), generate_sql)
  table.db.exec(sql, o, log = false)


# table.update -------------------------------------------------------------------------------------
proc update*[T](table: DbTable, o: T): void =
  table.log.with((table: table.name, id: o.id)).info "{table}.update id={id}"
  let generate_sql = proc (): string =
    let setters = T.fields.filter((n) => n != "id").map((n) => fmt"{n} = :{n}").join(", ")
    fmt"""
      update {table.name}
      set
        {setters}
      where id = :id
    """.dedent
  let sql = sql_cache.mget(("update", $o), generate_sql)
  table.db.exec(sql, o, log = false)


# table.save ---------------------------------------------------------------------------------------
proc save*[T](table: DbTable, o: T): void =
  table.log.with((table: table.name, id: o.id)).info "{table}.save id={id}"
  let generate_sql = proc (): string =
    let column_names = " " & T.fields.join(",  ")
    let named_values = T.fields.map((n) => fmt":{n}").join(", ")
    let setters = T.fields.filter((n) => n != "id").map((n) => fmt"{n} = :{n}").join(", ")
    fmt"""
      insert into {table.name}
        ({column_names})
      values
        ({named_values})
      on conflict (id) do update
      set
        {setters}
    """.dedent
  let sql = sql_cache.mget(("save", $o), generate_sql)
  table.db.exec(sql, o, log = false)


# table.save ---------------------------------------------------------------------------------------
proc find*[T](table: DbTable, : T): void =
  table.log.with((table: table.name, id: o.id)).info "{table}.save id={id}"
  let generate_sql = proc (): string =
    let column_names = " " & T.fields.join(",  ")
    let named_values = T.fields.map((n) => fmt":{n}").join(", ")
    let setters = T.fields.filter((n) => n != "id").map((n) => fmt"{n} = :{n}").join(", ")
    fmt"""
      insert into {table.name}
        ({column_names})
      values
        ({named_values})
      on conflict (id) do update
      set
        {setters}
    """.dedent
  let sql = sql_cache.mget(("save", $o), generate_sql)
  table.db.exec(sql, o, log = false)


# table.count ---------------------------------------------------------------------------------------
# proc save*[T](table: DbTable, o: T): void =
#   table.log.with((table: table.name, id: o.id)).info "{table}.save id={id}"
#   let generate_sql = proc (): string =
#     let column_names = " " & T.fields.join(",  ")
#     let named_values = T.fields.map((n) => fmt":{n}").join(", ")
#     let setters = T.fields.filter((n) => n != "id").map((n) => fmt"{n} = :{n}").join(", ")
#     fmt"""
#       insert into {table.name}
#         ({column_names})
#       values
#         ({named_values})
#       on conflict (id) do update
#       set
#         {setters}
#     """.dedent
#   let sql = sql_cache.mget(("save", $o), generate_sql)
#   table.db.exec(sql, o, log = false)


# --------------------------------------------------------------------------------------------------
# Test ---------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
if is_main_module:
  # Creating DB and defining schema
  let db    = Db.init("nim_test")

  let schema = """
    drop table if exists users;

    create table users(
      id   integer      not null,
      name varchar(100) not null,
      age  integer      not null,

      primary key (id)
    );
  """
  db.exec schema


  # Defining User Model
  type User = object
    id:   int
    name: string
    age:  int

  let users = db.table(User, "users")

  var jim = User(id: 1, name: "Jim", age: 30)
  users.save jim

  jim.age = 31
  users.save jim