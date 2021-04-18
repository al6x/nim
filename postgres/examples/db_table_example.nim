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