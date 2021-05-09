import basem, db_tablem, timem, randomm, jsonm


# User ---------------------------------------------------------------------------------------------
type User* = object
  id*:         int
  nick*:       string
  token*:      string

  case is_anon: bool
  of true:
    discard
  of false:
    source_id*:  string  # like "github/1"
    name*:       Option[string]
    avatar*:     Option[string]
    email*:      string
    # created_at*: Time
    # updated_at*: Time

# User schema --------------------------------------------------------------------------------------
let db = Db.init
db.before sql"""
  create table if not exists users(
    id         serial       not null,
    nick       varchar(100) not null,
    token      varchar(100) not null,
    is_anon    boolean      not null,
    source_id  varchar(100),
    name       varchar(100),
    avatar     varchar(100),
    email      varchar(100),
    -- created_at timestamp    not null,
    -- updated_at timestamp    not null,

    primary key (id)
  );

  create unique index if not exists users_source_id on users (source_id);
  create unique index if not exists users_nick      on users (nick);
  create unique index if not exists users_email     on users (email);
"""

let users* = Db.init.table(User, "users", auto_id = true)


# SourceUser ---------------------------------------------------------------------------------------
type SourceUser* = ref object
  source*: string
  nick*:   string
  id*:     int
  email*:  string
  avatar*: Option[string]
  name*:   Option[string]


# create_or_update_from ----------------------------------------------------------------------------
proc create_or_update_from_source*(_: type[User], source: SourceUser): User =
  # Getting existing or creating new
  let source_id = fmt"{source.source}/{source.id}"
  var user = users.fget((source_id: source_id)).get(() =>
    User(is_anon: false, source_id: source_id)
  )

  user.is_anon = false

  # Updating user from source
  user.nick   = source.nick
  user.name   = source.name
  user.avatar = source.avatar
  user.email  = source.email

  # Generating new token
  user.token = secure_random_token()

  # Saving
  users.save user
  user


# create_or_update_anon ----------------------------------------------------------------------------
proc authenticate*(_: type[User], token: string, create_anon = false): Option[User] =
  let found = users.fget((token: token))
  if found.is_some:
    found
  elif create_anon:
    users.save User(
      is_anon: true,
      nick:    secure_random_token()[0..^6],
      token:   token
    )
    users[(token: token)].some
  else:
    User.none

if is_main_module:
  db.define "plot_dev"
  db.before(sql"drop table if exists users;", prepend = true)

  let source = SourceUser(
    source: "github",
    nick:   "jim",
    id:     1,
    email:  "some@email.com",
    avatar: string.none,
    name:   string.none
  )
  let jim = User.create_or_update_from_source(source)

  echo User.authenticate(jim.token).get.nick

  # echo User.authenticate("unknown")

  # echo User.authenticate("unknown", create_anon = true)

  let anon = (
    id:      10,
    is_anon: true,
    nick:    secure_random_token()[0..^6],
    token:   "d",
    a:       1
  )
  echo anon.to_json.parse_json.to(User)