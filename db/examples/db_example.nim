import basem, ../dbm

# No need to manage connections, it will be connected lazily and
# reconnected in case of connection error
let db = Db.init
db.define("nim_test")
# db.drop

# Executing schema befor any other DB query, will be executed lazily before the first use
db.before sql"""
  drop table if exists users;

  create table users(
    name varchar(100) not null,
    age  integer      not null
  );
"""

# SQL with `:named` parameters
db.exec(sql("""
  insert into users ( name,  age)
  values            (:name, :age)
  """,
  (name: "Jim", age: 30)
))

# Or `{param}` parameters
db.exec sql"""
  insert into users ( name,      age)
  values            ({"Sarah"}, {25})
  """

# Querying with `:named` parameters and auto-casting
assert db.get(
  sql("select name, age from users where name = :name", (name: "Jim")), tuple[name: string, age: int]
) == @[
  (name: "Jim", age: 30)
]

# Querying with `{param}` parameters and auto-casting
assert db.get(
  sql"""select name, age from users where name = {"Sarah"}""", tuple[name: string, age: int]
) == @[
  (name: "Sarah", age: 25)
]

# Querying single value
assert db.get_one(
  sql"select count(*) from users where age = {30}", int
) == 1