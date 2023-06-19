import base, mono/core, ext/parser
import ./support, ../../model

type LocationKind* = enum home, doc, shortcut, filter, warns, asset, unknown
type Location* = object
  sid*, did*: string
  case kind*:  LocationKind
  of home:     discard
  of doc:      discard # sid, did
  of shortcut: discard # sid
  of filter:   filter*: Filter
  of warns:    discard
  of asset:    asset*: string # sid, did
  of unknown:  url*: Url

proc encode_filter_url(f: Filter): Url
proc is_filter_url(u: Url): bool
proc decode_filter_url(u: Url): Filter

proc to_url*(l: Location): Url =
  case l.kind
  of home:     [].to_url
  of doc:      [l.sid, l.did].to_url
  of shortcut: [l.did].to_url
  of filter:   encode_filter_url(l.filter) # ["filter", l.text].to_url
  of warns:    ["warns"].to_url
  of asset:    ([l.sid, l.did] & l.asset.split("/")).to_url
  of unknown:  l.url

proc to_s*(l: Location): string =
  l.to_url.to_s

proc parse*(_: type[Location], u: Url): Location =
  if   u.path.len == 0:
    Location(kind: home)
  elif u.is_filter_url:
    Location(kind: filter, filter: decode_filter_url(u))
  elif u.path.len == 1 and u.path[0] == "warns":
    Location(kind: warns)
  elif u.path.len == 1:
    Location(kind: shortcut, did: u.path[0])
  elif u.path.len == 2:
    Location(kind: doc, sid: u.path[0], did: u.path[1])
  elif u.path.len > 2:
    Location(kind: asset, sid: u.path[0], did: u.path[1], asset: u.path[2..^1].join("/"))
  else:
    Location(kind: unknown, url: u)

proc warns_url*(): string =
  Location(kind: warns).to_s

proc home_url*(): string =
  Location(kind: home).to_s

proc doc_url*(sid, did: string): string =
  Location(kind: LocationKind.doc, sid: sid, did: did).to_s

proc asset_url*(sid, did, asset: string): string =
  var url = Location(kind: LocationKind.asset, sid: sid, did: did, asset: asset).to_url
  url.params["mono_id"] = mono_id
  url.to_s

proc filter_url*(filter: Filter): string =
  Location(kind: LocationKind.filter, filter: filter).to_s

# filter -------------------------------------------------------------------------------------------
proc encode_filter_url(f: Filter): Url =
  template encode(tag: int): string = tag.decode_tag.replace(' ', '-').to_lower
  let etags = (f.incl.mapit(encode(it)) & f.excl.mapit("-" & encode(it))).join(",")

  var path: seq[string]
  unless etags.is_empty: path.add ["tags", etags]
  unless f.query.is_empty: path.add ["query", f.query]
  if path.is_empty: path.add "query"
  path.to_url

proc is_filter_url(u: Url): bool =
  u.path.len >= 1 and u.path[0] in ["tags", "query"]

proc decode_filter_url(u: Url): Filter =
  var incl, excl: seq[int]; var query: string
  template parse_tags(s: string) =
    unless s.is_empty:
      for tag in s.split(","):
        if tag.starts_with '-': excl.add tag[1..^1].replace('-', ' ').encode_tag
        else:                   incl.add tag.replace('-', ' ').encode_tag

  for i in [0, 2]:
    if i + 1 < u.path.len:
      case u.path[i]
      of "tags":  parse_tags u.path[i + 1]
      of "query": query = u.path[i + 1]
      else:       throw "invalid url"

  Filter.init(incl = incl, excl = excl, query = query)