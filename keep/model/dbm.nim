import base, ext/vcache, ./docm, ./spacem, ./configm

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

proc ntags*(db: Db): Table[string, int] =
  for blk in db.blocks:
    for ntag in blk.ntags:
      result.inc ntag

proc ntags_cached*(db: Db): Table[string, int] =
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

proc home*(db: Db): Option[tuple[space: Space, doc: Doc]] =
  # Page that will be shown as home page, any page marked with "home" tag
  for sid, space in db.spaces:
    for did, doc in space.docs:
      if "home-page" in doc.ntags:
        return (space, doc).some

proc get*(db: Db, sid, did: string): Option[(Space, Doc)] =
  if sid in db.spaces:
    let space = db.spaces[sid]
    if did in space.docs:
      let doc = space.docs[did]
      return (space, doc).some

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
