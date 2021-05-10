import basem, db_tablem, timem, randomm, jsonm, parsersm


# User ---------------------------------------------------------------------------------------------
# TODO 2 change to `ref object` when this issue will be resolved https://github.com/nim-lang/Nim/issues/17986
type User* = object
  id*:         string
  token*:      string

  case is_anon: bool  # virtual attribute
  of true:
    discard
  of false:
    source_id*:  string  # like "github/1"
    name*:       Option[string]
    avatar*:     Option[string]
    email*:      string
    # created_at*: Time
    # updated_at*: Time

proc `==`*(a, b: User): bool =
  a.to_json == b.to_json

proc from_json_hook*(v: var User, json: JsonNode) =
  v = User(is_anon: false)
  v.update_from json

proc custom_column_names*(user: User): seq[string] =
  user.field_names.filter((n) => n notin ["is_anon"])

# User schema --------------------------------------------------------------------------------------
let db = Db.init
db.before sql"""
  create table if not exists users(
    id         varchar(100) not null,
    token      varchar(100) not null,
    source_id  varchar(100),
    name       varchar(100),
    avatar     varchar(100),
    email      varchar(100),
    -- created_at timestamp    not null,
    -- updated_at timestamp    not null,

    primary key (id)
  );

  create unique index if not exists users_source_id on users (source_id);
  create unique index if not exists users_email     on users (email);
"""

let users* = Db.init.table(User, "users")


# SourceUser ---------------------------------------------------------------------------------------
type SourceUser* = ref object
  source*: string
  nick*:   string
  id*:     int
  email*:  string
  avatar*: Option[string]
  name*:   Option[string]


# create_or_update_from ----------------------------------------------------------------------------
proc create_or_update_from_source*(users: DbTable[User], source: SourceUser): User =
  # Getting existing or creating new
  let source_id = fmt"{source.source}/{source.id}"
  var user = users.fget((source_id: source_id)).get(() =>
    User(is_anon: false, source_id: source_id)
  )
  assert not user.is_anon

  # Updating user from source
  user.id =
    if   user.id != "":
      user.id # changing id not supported yet
    elif source.nick.starts_with "a_":
      secure_random_token(6) # "a_..." reserved for anonymous users
    elif source.nick.len < 3:
      source.nick & secure_random_token(3 - source.nick.len)
    else:
      source.nick
  user.name   = source.name
  user.avatar = source.avatar
  user.email  = source.email

  # Generating new token
  user.token = secure_random_token()

  # Saving
  users.save user
  user


# authenticate -------------------------------------------------------------------------------------
proc authenticate*(users: DbTable[User], token: string): User =
  users.fget((token: token)).get(() => User(
    is_anon: true,
    id:      "a_" & token[0..5],
    token:   token
  ))


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  db.define "plot_test"
  db.before(sql"drop table if exists users;", prepend = true)

  let source = SourceUser(
    source: "github",
    nick:   "jim",
    id:     1,
    email:  "some@email.com",
    avatar: string.none,
    name:   string.none
  )
  let jim = users.create_or_update_from_source(source)
  assert jim.id == "jim"

  assert users.authenticate(jim.token) == jim

  let anon = users.authenticate("unknown-token")
  assert anon.is_anon
  assert anon.token == "unknown-token"