import basem, logm, convertersm
import ./dbm, ./pg_convertersm, ./sqlm

export dbm, sqlm

# DbTable ------------------------------------------------------------------------------------------
type DbTable*[T] = ref object
  db*:   Db
  name*: string

proc log(table: DbTable): Log = Log.init("db", table.db.name)


# db.table -----------------------------------------------------------------------------------------
proc table*[T](db: Db, _: type[T], name: string): DbTable[T] =
  DbTable[T](db: db, name: name)


# table.create -------------------------------------------------------------------------------------
proc create*[T](table: DbTable[T], o: T): void =
  table.log.with((table: table.name, id: o.id)).info "{table}.create id={id}"
  let query = proc (): string =
    let field_names = T.field_names
    let column_names = " " & field_names.join(",  ")
    let named_values = field_names.map((n) => fmt":{n}").join(", ")
    fmt"""
      insert into {table.name}
        ({column_names})
      values
        ({named_values})
    """.dedent
  table.db.exec(sql(query(), o), log = false)


# table.update -------------------------------------------------------------------------------------
proc update*[T](table: DbTable[T], o: T): void =
  table.log.with((table: table.name, id: o.id)).info "{table}.update id={id}"
  let query = proc (): string =
    let setters = T.field_names.filter((n) => n != "id").map((n) => fmt"{n} = :{n}").join(", ")
    fmt"""
      update {table.name}
      set
        {setters}
      where id = :id
    """.dedent
  table.db.exec(sql(query(), o), log = false)


# table.save ---------------------------------------------------------------------------------------
proc save*[T](table: DbTable[T], o: T): void =
  table.log.with((table: table.name, id: o.id)).info "{table}.save id={id}"
  let query = proc (): string =
    let field_names = T.field_names
    let column_names = " " & field_names.join(",  ")
    let named_values = field_names.map((n) => fmt":{n}").join(", ")
    let setters = field_names.filter((n) => n != "id").map((n) => fmt"{n} = :{n}").join(", ")
    fmt"""
      insert into {table.name}
        ({column_names})
      values
        ({named_values})
      on conflict (id) do update
      set
        {setters}
    """.dedent
  table.db.exec(sql(query(), o), log = false)


# table.find ---------------------------------------------------------------------------------------
proc find*[T](table: DbTable[T], where: SQL = "", log = true): seq[T] =
  if log: table.log.with((table: table.name, where: $where)).info "{table}.find '{where}'"
  let query = proc (): string =
    let column_names = T.field_names.join(", ")
    let where_query = if where.query == "": "" else: fmt"where {where.query}"
    fmt"""
      select {column_names}
      from {table.name}
      {where_query}
    """.dedent
  table.db.get((query: query(), values: where.values).SQL, T, log = false)

proc find*[T](table: DbTable[T], where: string, values: object | tuple): seq[T] =
  table.find(sql(where, values))


# table.find_by_id ---------------------------------------------------------------------------------
proc find_by_id*[T](table: DbTable[T], id: string | int): Option[T] =
  table.log.with((table: table.name, id: id)).info "{table}.get {id}"
  let found = table.find(sql("id = :id", (id: id)), log = false)
  if found.len > 1: throw fmt"found {found.len} objects for id = '{id}'"
  if found.is_empty: T.none else: found[0].some


# table.count --------------------------------------------------------------------------------------
proc count*[T](table: DbTable[T], where: SQL = ""): int =
  table.log.with((table: table.name, where: $where)).info "{table}.count '{where}'"
  let query_prefix = fmt"""
    select count(*)
    from {table.name}""".dedent
  let query = if where.query == "":
    sql query_prefix
  else:
    (query: fmt"{query_prefix} where {where.query}", values: where.values)
  table.db.count(query, log = false)

proc count*[T](table: DbTable[T], where: string, values: object | tuple): int =
  table.count(sql(where, values))


# [] -----------------------------------------------------------------------------------------------
proc `[]`*[T](table: DbTable[T], id: int | string): T =
  table.find_by_id(id).get

proc `[]`*[T](table: DbTable[T], id: int | string, default: T): T =
  table.find_by_id(id).get(default)


# --------------------------------------------------------------------------------------------------
# Test ---------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
if is_main_module:
  # Creating DB and defining schema
  let db    = Db.init("nim_test")

  db.before """
    drop table if exists users;

    create table users(
      id   integer      not null,
      name varchar(100) not null,
      age  integer      not null,

      primary key (id)
    );
  """


  # Defining User Model
  type User = object
    id:   int
    name: string
    age:  int

  let users = db.table(User, "users")

  # Saving
  var jim = User(id: 1, name: "Jim", age: 30)
  users.save jim

  jim.age = 31
  users.save jim

  # Find, count
  assert users.find("age = :age", (age: 31)) == @[jim]
  assert users.find_by_id(1)                 == jim.some
  assert users[1]                            == jim

  assert users.count("age = :age", (age: 31)) == 1
