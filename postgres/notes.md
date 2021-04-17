# Config

Disable pagination

`echo "\pset pager off" > ~/.psqlrc`

# Bash

- Start `pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start`
- Create database `createdb -U postgres nim_test`
- Drop database `dropdb -U postgres nim_test`

# Console

- Quit `\q`
- List databases `\l`

# Installation

```
createuser -s postgres
export PGUSER=postgres # set as default user
```

Set timezone to UTC in `/usr/local/var/postgres/postgresql.conf`
timezone = 'UTC'
log_timezone = 'UTC'