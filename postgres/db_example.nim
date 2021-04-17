import basem, ./dbm

# No need to manage connections, it will be connected lazily and
# reconnected in case of connection error
let db = Db.init("nim_test")


# Creating schema
db.exec("""
  begin;
  drop table if exists users;
  create table users(
    name       varchar(100)   not null,
    age        integer        not null
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