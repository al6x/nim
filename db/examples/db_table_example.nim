import basem, ../dbm, ../db_tablem

# No need to manage connections, it will be connected lazily and
# reconnected in case of connection error
let db = Db.init
db.define("nim_test")

# Executing schema befor any other DB query, will be executed lazily before the first use
db.before sql"""
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

# filter
assert users.filter(sql"age = {30}") == @[jim]
assert users.filter((age: 30))       == @[jim]
assert users.filter(1)               == @[jim]

# []
assert users[sql"age = {30}"] == jim
assert users[(age: 30)]       == jim
assert users[1]               == jim

# count, has
assert users.count((age: 30)) == 1
assert (age: 30) in users