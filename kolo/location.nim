import base, mono/core

type LocationKind* = enum doc, search, unknown
type Location* = object
  case kind*: LocationKind
  of doc:
    space*, doc*: string
  of search:
    text*: string
  of unknown:
    url*: Url

proc to_s*(l: Location): string =
  case l.kind
  of doc:
    [l.space, l.doc].to_url.to_s
  of search:
    ["search", l.text].to_url.to_s
  of unknown:
    l.url.to_s

proc parse*(_: type[Location], u: Url): Location =
  if u.path.len == 1 and u.path[0] == "search":
    Location(kind: search, text: u.params.get("q", ""))
  elif u.path.len == 2:
    Location(kind: doc, space: u.path[0], doc: u.path[1])
  else:
    Location(kind: unknown, url: u)

proc doc_url*(space, doc: string): string =
  Location(kind: LocationKind.doc, space: space, doc: doc).to_s

proc search_url*(text: string): string =
  Location(kind: search, text: text).to_s