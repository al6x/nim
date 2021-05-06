import basem, db_tablem, timem

type User* = ref object
  id*:         int
  nick*:       string
  name*:       string
  email*:      string
  tokens*:     seq[string]
  created_at*: Time
  updated_at*: Time

let db = Db.init
db.before sql"""
  create table if not exists users(
    id         serial       not null,
    nick       varchar(100) not null,
    name       varchar(100) not null,
    email      varchar(100) not null,
    tokens     varchar(100) not null,
    created_at timestamp    not null,
    updated_at timestamp    not null

    primary key (id)
  );

  create unique index if not exists users_nick  on users (nick);
  create unique index if not exists users_email on users (email);
"""

let users* = Db.init.table(User, "users")