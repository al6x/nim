import base, mono/core, ext/parser
import ./support, ../model

type LocationKind* = enum home, record, shortcut, filter, warns, asset, unknown
type Location* = object
  sid*, rid*: string
  case kind*:  LocationKind
  of home:     discard
  of record:   discard # sid, rid
  of shortcut: discard # sid
  of filter:
    filter*: Filter
    page*:   int
  of warns:    discard
  of asset:    asset*: string # sid, rid
  of unknown:  url*: Url

proc to_url(f: Filter): Url
proc is_filter_url(u: Url): bool
proc from_url(_: type[Filter], u: Url): Filter

proc to_url*(l: Location): Url =
  case l.kind
  of home:     [].to_url
  of record:   [l.sid, l.rid].to_url
  of shortcut: [l.rid].to_url
  of filter:
    var url = l.filter.to_url
    if l.page > 1: url.params["page"] = l.page.to_s
    url
  of warns:    ["warns"].to_url
  of asset:    ([l.sid, l.rid] & l.asset.split("/")).to_url
  of unknown:  l.url

proc to_s*(l: Location): string =
  l.to_url.to_s

proc parse*(_: type[Location], u: Url): Location =
  if   u.path.len == 0:
    Location(kind: home)
  elif u.is_filter_url:
    Location(kind: filter, filter: Filter.from_url(u), page: int.parse(u.params.get("page", "1")))
  elif u.path.len == 1 and u.path[0] == "warns":
    Location(kind: warns)
  elif u.path.len == 1:
    Location(kind: shortcut, rid: u.path[0])
  elif u.path.len == 2:
    Location(kind: record, sid: u.path[0], rid: u.path[1])
  elif u.path.len > 2:
    Location(kind: asset, sid: u.path[0], rid: u.path[1], asset: u.path[2..^1].join("/"))
  else:
    Location(kind: unknown, url: u)

proc warns_url*(): string =
  Location(kind: warns).to_s

proc home_url*(): string =
  Location(kind: home).to_s

proc full_url*(record: Record): string =
  Location(kind: LocationKind.record, sid: record.sid, rid: record.id).to_s

proc short_url*(record: Record): string =
  for id, space in db.spaces:
    if id != record.sid and record.id in space.records: return full_url(record)
  [record.id].to_url.to_s

proc url*(record: Record, short = true): string =
  result = if short: record.short_url else: record.full_url
  # unless blk.id.is_empty: result.add "#" & blk.id

proc short_url*(blk: Block): string =
  blk.url(short = true)

proc asset_url*(sid, rid, asset: string): string =
  var url = Location(kind: LocationKind.asset, sid: sid, rid: rid, asset: asset).to_url
  url.params["mono_id"] = mono_id
  url.to_s

proc filter_url*(filter: Filter, page: int): string =
  Location(kind: LocationKind.filter, filter: filter, page: page).to_s

proc tag_url*(tag: string): string =
  ["tags", tag.to_lower].to_url.to_s

# filter -------------------------------------------------------------------------------------------
proc to_url(f: Filter): Url =
  # template encode(tag: int): string = tag.decode_tag.replace(' ', '-').to_lower
  # let etags = (f.incl.mapit(encode(it)).sort & f.excl.mapit("-" & encode(it)).sort).join(",")
  let etags = (f.incl.sort & f.excl.mapit("-" & it).sort).join(",")

  var path: seq[string]
  unless etags.is_empty:   path.add ["tags", etags]
  unless f.query.is_empty: path.add ["query", f.query]
  if path.is_empty: path.add "tags"
  path.to_url

proc is_filter_url(u: Url): bool =
  u.path.len >= 1 and u.path[0] in ["tags", "query"]

proc from_url(_: type[Filter], u: Url): Filter =
  var incl, excl: seq[string]
  let tags = u.get("tags", "")
  unless tags.is_empty:
    for tag in tags.split(","):
      if tag.starts_with '-': excl.add tag[1..^1].replace('-', ' ')
      else:                   incl.add tag.replace('-', ' ')
  Filter.init(incl = incl, excl = excl, query = u.get("query", ""))