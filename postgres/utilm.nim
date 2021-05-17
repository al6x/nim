import base/basem
from uri import nil

type PgUrl* = object
  url*:      string
  host*:     string
  port*:     int
  name*:     string
  user*:     string
  password*: string

proc parse*(_: type[PgUrl], name_or_url: string): PgUrl =
  let url = if ":" in name_or_url: name_or_url
  else:                            fmt"postgresql://postgres@localhost:5432/{name_or_url}"

  var parsed = uri.init_uri(); uri.parse_uri(url, parsed)
  PgUrl(
    url: url,
    host: parsed.hostname, port: parsed.port.parse_int, name: parsed.path[1..^1],
    user: parsed.username, password: parsed.password
  )