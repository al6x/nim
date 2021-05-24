import base/[basem, logm, parsersm, jsonm, timem]
import ./sqlm, ./dbm

export sqlm, dbm

type KVDb = object
  db*: Db

proc init*(_: type[KVDb], db: Db): KVDb =
  db.before(sql"""
    create table if not exists kv(
      scope      varchar(100)   not null,
      key        varchar(100)   not null,
      value      varchar(10000) not null,
      created_at timestamp      not null,
      updated_at timestamp      not null,

      primary key (scope, key)
    );
  """, (info: "applying kvdb schema"))
  KVDb(db: db)

proc log(kv: KVDb): Log = Log.init(kv.db.id, "kv")

proc sql_where_info*(sql: SQL, msg: string): tuple =
  let formatted_sql: string = sql.inline
  (where: formatted_sql, info: msg & " '{where}'")


# [] and []= ---------------------------------------------------------------------------------------
proc fget*(kvdb: KVDb, scope: string, key: string): Option[string] =
  kvdb.log.with((scope: scope, key: key)).info("get {scope}/{key}")
  kvdb.db.fget_value(sql"select value from kv where scope = {scope} and key = {key}", string, ())

proc `[]`*(kvdb: KVDb, scope: string, key: string): string =
  kvdb.fget(scope, key).get

proc `[]`*(kvdb: KVDb, scope: string, key: string, default: string): string =
  kvdb.fget(scope, key).get(default)

proc `[]=`*(kvdb: KVDb, scope: string, key: string, value: string): void =
  kvdb.log.with((scope: scope, key: key)).info("set {scope}/{key}")
  let now = Time.now
  kvdb.db.exec(sql"""
    insert into kv
      (scope,   key,   value,   created_at,  updated_at)
    values
      ({scope}, {key}, {value}, {now},       {now})
    on conflict (scope, key) do update
    set
      value = excluded.value, updated_at = excluded.updated_at
  """, ())


# del ----------------------------------------------------------------------------------------------
proc del*(kvdb: KVDb, scope: string, key: string): Option[string] =
  result = kvdb.fget(scope, key)
  kvdb.log.with((scope: scope, key: key)).info("del {scope}/{key}")
  kvdb.db.exec(sql"delete from kv where scope = {scope} and key = {key}", ())

proc del*[T](kvdb: KVDb, _: type[T], key: string): Option[T] =
  let scope = T.type.to_s & "_type"
  result = kvdb.get_optional(scope, key)
  kvdb.del(scope, key)

proc del_all*(kvdb: KVDb): void =
  kvdb.log.info("del_all")
  kvdb.db.exec(sql"delete from kv", ())

# T.[], T.[]= --------------------------------------------------------------------------------------
proc fget*[T](kvdb: KVDb, _: type[T], key: string): Option[T] =
  kvdb.fget($(T.type) & "_type", key).map((raw) => raw.parse_json.json_to(T))

proc `[]`*[T](kvdb: KVDb, _: type[T], key: string): T =
  kvdb.fget(T, key).get

proc `[]`*[T](kvdb: KVDb, _: type[T], key: string, default: T): T =
  kvdb.fget(T, key).get(default)

proc `[]=`*[T](kvdb: KVDb, _: type[T], key: string, value: T): void =
  kvdb[$(T.type) & "_type", key] = value.to_json.to_s


# Test ---------------------------------------------------------------------------------------------
slow_test "KVDb":
  let db = Db.init("db", "nim_test")
  let kvdb = KVDb.init(db)
  kvdb.del_all

  # String values
  assert kvdb["test", "a", "none"] == "none"
  kvdb["test", "a"] = "b"
  assert kvdb["test", "a", "none"] == "b"

  # Object values
  type A = object
    id: string

  assert kvdb[A, "a", A(id: "none")] == A(id: "none")
  kvdb[A, "a"] = A(id: "a")
  assert kvdb[A, "a", A(id: "none")] == A(id: "a")

  db.close