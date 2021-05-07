import basem, dbm, timem, jsonm

let db = Db.init

db.before sql"""
  create table if not exists kv(
    scope      varchar(100)   not null,
    key        varchar(100)   not null,
    value      varchar(10000) not null,
    created_at timestamp      not null,
    updated_at timestamp      not null,

    primary key (scope, key)
  );
"""

type KVDb = object
let kvdb* = KVDb()


# [] and []= ---------------------------------------------------------------------------------------
proc get_optional*(kvdb: KVDb, scope: string, key: string): Option[string] =
  db.get_one_optional(sql"select value from kv where scope = {scope} and key = {key}", string)

proc `[]`*(kvdb: KVDb, scope: string, key: string): string =
  kvdb.get_optional(scope, key).get

proc `[]`*(kvdb: KVDb, scope: string, key: string, default: string): string =
  kvdb.get_optional(scope, key).get(default)

proc `[]=`*(kvdb: KVDb, scope: string, key: string, value: string): void =
  let now = Time.now
  db.exec sql"""
    insert into kv
      (scope,   key,   value,   created_at,  updated_at)
    values
      ({scope}, {key}, {value}, {now},       {now})
    on conflict (scope, key) do update
    set
      value = excluded.value, updated_at = excluded.updated_at
  """


# T.[], T.[]= --------------------------------------------------------------------------------------
proc get_optional*[T](kvdb: KVDb, _: type[T], key: string): Option[T] =
  kvdb.get_optional($(T.type) & "_type", key).map((raw) => raw.parse_json.to(T))

proc `[]`*[T](kvdb: KVDb, _: type[T], key: string): T =
  kvdb.get_optional(T, key).get

proc `[]`*[T](kvdb: KVDb, _: type[T], key: string, default: T): T =
  kvdb.get_optional(T, key).get(default)

proc `[]=`*[T](kvdb: KVDb, _: type[T], key: string, value: T): void =
  kvdb[$(T.type) & "_type", key] = value.to_json


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  db.before sql"delete from kv;"
  db.define("nim_test")

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