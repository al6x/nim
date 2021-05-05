import basem, logm, parsersm
import ./sqlm, ./dbm

export sqlm, dbm

# DbTable ------------------------------------------------------------------------------------------
type DbTable*[T] = ref object
  db*:   Db
  name*: string

proc log[T](table: DbTable[T]): Log = Log.init("db", table.db.name)


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
    let setters = field_names.filter((n) => n != "id").map((n) => fmt"{n} = excluded.{n}").join(", ")
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


# build_table_query --------------------------------------------------------------------------------
proc build_table_query[W](table_name: string, select: string, where: W, normalise = false): SQL =
  let (where_conditions, values) =
    when where is SQL:
      where
    elif where is tuple:
      let conditions = W.field_names.map((name) => fmt"{name} = :{name}").join(" and ")
      sql(conditions, where)
    elif where is string or where is int:
      sql "id = {where}"
    else:
      throw fmt"unsupported where clause {where}"

  var query = fmt"""
    select {select}
    from   {table_name}
    where  {where_conditions}
  """.dedent

  if normalise: # used for testing
    query = query.replace("\n", " ").replace(re"\s+", " ").replace(re"\s+$", "")

  sql(query, values)

test "build_query":
  assert build_table_query(
    "users", "*", sql"id = {1}", normalise = true
  ) == sql(
    "select * from users where id = :id", (id: 1)
  )

  assert build_table_query(
    "users", "*", (id: 1), normalise = true
  ) == sql(
    "select * from users where id = :id", (id: 1)
  )

  assert build_table_query(
    "users", "*", 1, normalise = true
  ) == sql(
    "select * from users where id = :id", (id: 1)
  )

# table.filter -------------------------------------------------------------------------------------
proc filter*[T, W](table: DbTable[T], where: W = sql"", log = true): seq[T] =
  if log: table.log.with((table: table.name, where: $where)).info "{table}.get {where}"
  let column_names = T.field_names.join(", ")
  let query = build_table_query(table.name, column_names, where)
  table.db.get(query, T, log = false)


# table.get_one -----------------------------------------------------------------------------------
proc fget*[T, W](table: DbTable[T], where: W = sql"", log = true): Option[T] =
  if log: table.log.with((table: table.name, where: $where)).info "{table}.get_one {where}"
  let found = table.filter(where, log = false)
  if found.len > 1: throw fmt"expected one but found {found.len} objects"
  if found.len > 0: found[0].some else: T.none


# table.count --------------------------------------------------------------------------------------
proc count*[T, W](table: DbTable[T], where: W = sql""): int =
  table.log.with((table: table.name, where: $where)).info "{table}.count {where}"
  let query = build_table_query(table.name, "count(*)", where)
  table.db.get_one(query, int, log = false)


# table.contains -----------------------------------------------------------------------------------
proc contains*[T, W](table: DbTable[T], where: W = sql""): bool =
  table.count(where) > 0


# [] -----------------------------------------------------------------------------------------------
proc `[]`*[T, W](table: DbTable[T], where: W): T =
  table.fget(where).get

proc `[]`*[T, W](table: DbTable[T], where: W, default: T): T =
  table.fget(where).get(default)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let db = Db.init("nim_test")

  db.before sql"""
    drop table if exists test_db_table_users;

    create table test_db_table_users(
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

  let users = db.table(User, "test_db_table_users")

  # Saving
  var jim = User(id: 1, name: "Jim", age: 30)
  users.save jim

  jim.age = 31
  users.save jim

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

  # Cleaning
  db.exec sql"drop table if exists test_db_table_users"
