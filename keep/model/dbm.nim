import base, ext/[vcache, grams, search], ./schema, ./configm

type Db* = ref object
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
proc tags*(db: Db): Table[string, int] =
  for record in db:
    record.tags.eachit(result.inc it)

proc tags_cached*(db: Db): Table[string, int] =
  db.cache.get_into("tags", db.version, result, db.tags)

proc records_with_warns*(db: Db): seq[Record] =
  for record in db:
    if not record.warns.is_empty: result.add record
  result = result.sortit(it.id)

proc records_with_warns_cached*(db: Db): seq[Record] =
  db.cache.get_into("records_with_warns", db.version, result, db.records_with_warns)

iterator filter*(db: Db, incl, excl: seq[string]): Record =
  for record in db:
    if incl.is_all_in(record.tags) and excl.is_none_in(record.tags):
      yield record

# proc search*(db: Db, incl, excl: seq[int], query: string): seq[Matches[Record]] =
#   let score_fn = build_score[Record](query)
#   for record in db.filter(incl, excl):
#     score_fn(record, result)
#   result = result.sortit(-it.score)

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
