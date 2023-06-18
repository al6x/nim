import base, ext/[vcache, grams, search], ./docm, ./spacem, ./configm

type Db* = ref object
  version*:     int
  config*:      Config
  spaces*:      Table[string, Space]
  cache*:       VCache
  # space_cache*: Table[(string, string), VCacheContainer]
  bgjobs*:      seq[proc()]

var db* {.threadvar.}: Db

proc log*(db: Db): Log =
  Log.init("Db")

proc init*(_: type[Db], config = Config()): Db =
  Db(config: config)

proc non_processed_version*(db: Db): int =
  var h: Hash = db.config.version.hash
  for sid, space in db.spaces:
    h = h !& sid.hash !& space.version.hash
  !$h

iterator blocks*(db: Db): Block =
  for _, space in db.spaces:
    for _, doc in space.docs:
      for blk in doc.blocks:
        yield blk

iterator docs*(db: Db): Doc =
  for _, space in db.spaces:
    for _, doc in space.docs:
      yield doc

proc validate_tags*(space: Space, config: Config) =
  if not config.allowed_tags.is_empty:
    for blk in space.blocks:
      for tag in blk.tags:
        if tag notin config.allowed_tags:
          blk.warns.add fmt"Invalid tag: {tag}"

proc validate_links*(space: Space, db: Db) =
  for blk in space.blocks:
    for link in blk.links:
      let (sid, did, bid) = link
      try:
        let doc = (if sid == ".": space else: db.spaces[sid]).docs[did]
        unless bid.is_empty: discard doc.blockids[bid]
      except:
        blk.warns.add fmt"Invalid link: {link.to_s}"

proc ntags*(db: Db): Table[int, int] =
  for blk in db.blocks:
    for ntag in blk.ntags:
      result.inc ntag

proc ntags_cached*(db: Db): Table[int, int] =
  db.cache.get_into("ntags", db.version, result, db.ntags)

proc docs_with_warns*(db: Db): seq[tuple[sid, did: string]] =
  for sid, space in db.spaces:
    for did, doc in space.docs:
      unless doc.warns.is_empty:
        result.add (sid, did)
        continue
      block blocks_loop:
        for blk in doc.blocks:
          unless blk.warns.is_empty:
            result.add (sid, did)
            break blocks_loop
  result = result.sortit(it[1])

proc docs_with_warns_cached*(db: Db): seq[tuple[sid, did: string]] =
  db.cache.get_into("docs_with_warns", db.version, result, db.docs_with_warns)

proc get*(db: Db, sid, did: string): Option[Doc] =
  for sid, space in db.spaces:
    if did in space.docs:
      return space.docs[did].some

proc get_doc*(db: Db, did: string): Option[Doc] =
  for sid, space in db.spaces:
    if did in space.docs:
      return space.docs[did].some

iterator filter_blocks*(db: Db, incl, excl: seq[int]): Block =
  for _, space in db.spaces:
    for _, doc in space.docs:
      for blk in doc.blocks:
        if incl.is_all_in(blk.ntags) and incl.is_none_in(blk.ntags):
          yield blk

proc filter_blocks*(db: Db, incl, excl: seq[int], query: string): seq[Matches[Block]] =
  let score_fn = build_score[Block](query)
  for blk in db.filter_blocks(incl, excl):
    score_fn(blk, result)
  result = result.sortit(-it.score)

# processing ---------------------------------------------------------------------------------------
proc process*(db: Db) =
  db.cache.process("process(db)", db.non_processed_version):
    db.log.info "process"
    for sid, space in db.spaces:
      space.validate_tags db.config
      space.validate_links db
      # for fn in space.processors: fn()
    # Processing changes version of the database, so the db.version should be used for calculations
    # that depends on processing.
    db.version = db.non_processed_version

# proc get*[T](db: Db, fn: (proc(db: Db): T)): T =
#   db.cache.get("proc/" & fn.repr)

proc process_bgjobs*(db: Db) =
  for fn in db.bgjobs: fn()

template build_db_process_cb*(db): auto =
  let db_process = build_sync_timer(100, () => db.process)
  let db_bgjobs  = build_sync_timer(500, () => db.process_bgjobs)
  proc =
    db_process()
    db_bgjobs()
