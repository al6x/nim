import base, ext/[vcache], ./schema, ./configm, ./filter
from ext/search import is_all_in, is_none_in

type
  Db* = ref object
    version*:     int
    config*:      Config
    spaces*:      Table[string, Space]
    cache*:       VCache
    # space_cache*: Table[(string, string), VCacheContainer]
    bgjobs*:      seq[proc()]
    warns*:       seq[string]

var db* {.threadvar.}: Db

proc log*(db: Db): Log =
  Log.init("Db")

proc init*(_: type[Db], config = Config.init): Db =
  Db(config: config)

proc unprocessed_version(db: Db): int =
  var h: Hash = db.config.version.hash
  for sid, space in db.spaces:
    h = h !& (sid, space.version).hash
  !$h

template process_if_needed(db: Db, code) =
  db.cache.process("process(db)", db.unprocessed_version):
    db.log.info "process"
    code
    db.version = db.unprocessed_version # Processing may change content of the database

# helpers ------------------------------------------------------------------------------------------
proc contains*(db: Db, sid: string): bool =
  sid in db.spaces

proc `[]`*(db: Db, sid: string): Space =
  db.spaces[sid]

proc get*(db: Db, sid: string): Option[Space] =
  if sid in db.spaces: return db.spaces[sid].some

proc contains*(db: Db, id: RecordId): bool =
  id[0] in db.spaces and id[1] in db.spaces[id[0]]

proc `[]`*(db: Db, id: RecordId): Record =
  db.spaces[id[0]].records[id[1]]

proc get*(db: Db, id: RecordId): Option[Record] =
  if id[0] in db.spaces:
    let space = db.spaces[id[0]]
    if id[1] in space.records:
      return space.records[id[1]].some

proc ids*(records: openarray[Record]): seq[RecordId] =
  records.mapit((it.sid, it.id).RecordId)

proc get*(db: Db, ids: seq[RecordId]): seq[Record] =
  for id in ids: result.add db[id]

proc get_by_rid*(db: Db, rid: string): Option[Record] =
  for _, space in db.spaces:
    if rid in space.records: return space.records[rid].some

iterator items*(db: Db): Record =
  for _, space in db.spaces:
    for record in space:
      yield record

# Validations --------------------------------------------------------------------------------------
proc validate_tags*(db: Db) =
  if not db.config.allowed_tags.is_empty:
    for record in db:
      for tag in record.tags:
        if tag notin db.config.allowed_tags:
          record.warns.add fmt"Invalid tag: {tag}"

proc validate_links*(db: Db) =
  for record in db:
    for id in record.links:
      if id notin db:
        record.warns.add fmt"Invalid link: {id}"

# Stats --------------------------------------------------------------------------------------------
template tags_stats*(records_iterable: untyped): Table[string, int] =
  var result = Table[string, int].init
  for record in records_iterable:
    record.tags.eachit(result.inc it)
  result

proc tags_stats_cached*(db: Db): Table[string, int] =
  db.cache.get_into("tags", db.version, result, db.tags_stats)

proc records_with_warns*(db: Db): seq[Record] =
  for record in db:
    if not record.warns.is_empty: result.add record
  result = result.sortit(it.id)

proc records_with_warns_cached*(db: Db): seq[Record] =
  db.get db.cache.get("records_with_warns", db.version, seq[RecordId], db.records_with_warns.ids)

iterator filter*(db: Db, incl, excl: seq[string]): Record =
  for record in db:
    if incl.is_all_in(record.tags) and excl.is_none_in(record.tags) and not (record of Container):
      yield record

iterator search_substring*(db: Db, incl, excl: seq[string], query: string): Matches =
  let query = query.to_lower
  for record in db.filter(incl, excl):
    if query in record.text:
      let matches = record.text.find_all(query).mapit((1.0, it).Match)
      yield (1.0, record, matches)

# processing ---------------------------------------------------------------------------------------
proc process*(db: Db) =
  db.process_if_needed:
    db.validate_tags
    db.validate_links

proc process_bgjobs*(db: Db) =
  for fn in db.bgjobs: fn()

template build_db_process_cb*(db): auto =
  let db_process = build_sync_timer(100, () => db.process)
  let db_bgjobs  = build_sync_timer(500, () => db.process_bgjobs)
  proc =
    db_process()
    db_bgjobs()


# proc search*(db: Db, incl, excl: seq[int], query: string): seq[Matches[Record]] =
#   # Match* = tuple[score: float, l, h: int]
#   # Matches* = tuple[score: float, record: Record, matches: seq[Match]]
#   let score_fn = build_score[Record](query)
#   for record in db.filter(incl, excl):
#     score_fn(record, result)
#   result = result.sortit(-it.score)