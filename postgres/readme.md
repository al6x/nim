PostgreSQL with basic ORM support.

Made by [al6x](http://al6x.com).

# Features

- Named parameters in SQL.
- Auto-casting between Nim and SQL types.
- Auto-casting SQL results to Nim objects, named or unnamed tuples.
- No explicit connection management.
- Auto-reconnect if connection fail.
- Support for `null` and `Option`.

# Db example

```Nim
import basem, ../dbm

# No need to manage connections, it will be connected lazily and
# reconnected in case of connection error
let db = Db.init("nim_test")


# Creating schema
let schema = """
  drop table if exists users;

  create table users(
    name       varchar(100)   not null,
    age        integer        not null
  );
  """
db.exec schema


# SQL with `:named` parameters instead of `?`
db.exec("""
  insert into users ( name,  age)
  values            (:name, :age)
  """,
  (name: "Jim", age: 33)
)


# Conversion to objects, named or unnamed tuples
let rows = db.get("""
  select name, age
  from users
  where age > :min_age
  """,
  (min_age: 10),
  tuple[name: string, age: int]
)
assert rows == @[(name: "Jim", age: 33)]
```

# ORM example

```Nim
import basem, ../db_tablem

# Creating DB and defining schema
let db = Db.init("nim_test")

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
assert users.find("age = :age", (age: 31)) == @[jim]
assert users.find_by_id(1)                 == jim.some
assert users[1]                            == jim

assert users.count("age = :age", (age: 31)) == 1
```