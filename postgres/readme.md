PostgreSQL driver with basic ORM support.

# Features

- Lazy connection to save startup time
- Auto-reconnect if connection fail
- Support for `null` and `Option`
- Named parameters in SQL

# Examples

```Nim
import basem, ./dbm

# No need to manage connections, it will be connected lazily and
# reconnected in case of connection error
let db = Db.init("nim_test")


# Creating schema
db.exec("""
  begin;
  drop table if exists users;

  create table if not exists users(
    id         serial         not null,
    name       varchar(100)   not null,
    age        integer        not null,

    primary key (id)
  );
  commit;""")


# SQL with `:named` parameters instead of `?`
db.exec("""
  insert into users ( name,  age)
  values            (:name, :age)""",
  (name: "Jim", age: 33))


# Conversion to objects, named or unnamed tuples
assert db.get("""
  select name, age
  from users
  where age > :min_age""",
  (min_age: 10),
  tuple[name: string, age: int]
) == @[
  (name: "Jim", age: 33)
]
```

# Problems

- When `null` returned from Postgres for the field of `string` type, there's no way to distinguish
  it from the empty string.
