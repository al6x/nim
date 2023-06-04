import base, mono/core

type LocationKind* = enum home, doc, shortcut, search, asset, unknown
type Location* = object
  sid*, did*: string
  case kind*:  LocationKind
  of home:     discard
  of doc:      discard # sid, did
  of shortcut: discard # sid
  of search:   text*: string
  of asset:    asset*: string # sid, did
  of unknown:  url*: Url

proc to_url*(l: Location): Url =
  case l.kind
  of home:     [].to_url
  of doc:      [l.sid, l.did].to_url
  of shortcut: [l.did].to_url
  of search:   ["search", l.text].to_url
  of asset:    ([l.sid, l.did] & l.asset.split("/")).to_url
  of unknown:  l.url

proc to_s*(l: Location): string =
  l.to_url.to_s

proc parse*(_: type[Location], u: Url): Location =
  if u.path.len == 0:   Location(kind: home)
  elif u.path.len == 1:
    case u.path[0]
    of "search":        Location(kind: search, text: u.params.get("q", ""))
    else:               Location(kind: shortcut, did: u.path[0])
  elif u.path.len == 2: Location(kind: doc, sid: u.path[0], did: u.path[1])
  elif u.path.len > 2:  Location(kind: asset, sid: u.path[0], did: u.path[1], asset: u.path[2..^1].join("/"))
  else:                 Location(kind: unknown, url: u)

proc home_url*(): string =
  Location(kind: home).to_s

proc doc_url*(sid, did: string): string =
  Location(kind: LocationKind.doc, sid: sid, did: did).to_s

proc search_url*(text: string): string =
  Location(kind: search, text: text).to_s

proc asset_url*(sid, did, asset: string): string =
  var url = Location(kind: LocationKind.asset, sid: sid, did: did, asset: asset).to_url
  url.params["mono_id"] = session.id
  url.to_s