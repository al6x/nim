PostgreSQL with basic ORM support.

Made by [al6x](http://al6x.com).

# Features

- Named parameters in SQL.
- Auto-casting between Nim and SQL types, objects, tuples.
- No explicit connection management, auto-reconnect.
- Support for `null` and `Option`.

# Db example

```Nim
import basem, ../dbm

# No need to manage connections, it will be connected lazily and
# reconnected in case of connection error
let db = Db.init("nim_test")


# Creating schema
db.before """
  drop table if exists users;

  create table users(
    name       varchar(100)   not null,
    age        integer        not null
  );
  """


# SQL with `:named` parameters instead of `?`
db.exec(sql("""
  insert into users ( name,  age)
  values            (:name, :age)
  """,
  (name: "Jim", age: 33)
))


# Conversion to objects, named or unnamed tuples
let rows = db.get(sql"""
  select name, age
  from users
  where age > {10}
  """,
  tuple[name: string, age: int]
)
assert rows == @[(name: "Jim", age: 33)]


# Count
assert db.get_one(sql"select count(*) from users", int) == 1
```

# ORM example

```Nim
import basem, ../db_tablem

# Creating DB and defining schema
let db = Db.init("nim_test")

db.before """
  drop table if exists users;

  create table users(
    id   integer      not null,
    name varchar(100) not null,
    age  integer      not null,

    primary key (id)
  );
"""


# Defining User model
type User = object
  id:   int
  name: string
  age:  int

let users = db.table(User, "users")


# Save, create, update
var jim = User(id: 1, name: "Jim", age: 30)
users.save jim

jim.age = 31
users.save jim


# Find, get, count
assert users.get(sql"age = {31}")   == @[jim]
assert users.get_one(1)             == jim.some
assert users[1]                     == jim

assert users.count(sql"age = {31}") == 1
```


# Notes

- Use https://github.com/supabase/realtime + TCP exec string API for Notification Streams and
  Non-blocking Nim PostgreSQL driver. Or maybe use Deno?
- Another Streaming PostgreSQL Supabase https://github.com/supabase/supabase
- TypeScript in-memory SQL DB https://github.com/agershun/alasql and https://github.com/oguimbal/pg-mem
- Deno Postgres Driver https://github.com/denodrivers/postgres

# License

MIT