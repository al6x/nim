import basem, db_tablem, timem, randomm


# User ---------------------------------------------------------------------------------------------
type User* = ref object
  id*:         int
  source_id*:  string  # like "github/1"
  nick*:       string
  name*:       Option[string]
  avatar*:     Option[string]
  email*:      string
  token*:      string
  # created_at*: Time
  # updated_at*: Time

# User schema --------------------------------------------------------------------------------------
let db = Db.init
db.before sql"""
  create table if not exists users(
    id         serial       not null,
    source_id  varchar(100) not null,
    nick       varchar(100) not null,
    name       varchar(100),
    avatar     varchar(100),
    email      varchar(100) not null,
    token      varchar(100) not null,
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
    User(source_id: source_id)
  )

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