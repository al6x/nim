import base, ext/vcache, ./docm, ./spacem, ./configm

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

proc process*(db: Db) =
  db.cache.process("process(db)", db.non_processed_version):
    db.log.info "process"
    for sid, space in db.spaces:
      space.validate_tags
      space.validate_links db
      # for fn in space.processors: fn()
    # Processing changes version of the database, so the db.version should be used for calculations
    # that depends on processing.
    db.version = db.non_processed_version

# proc get*[T](db: Db, fn: (proc(db: Db): T)): T =
#   db.cache.get("proc/" & fn.repr)

proc process_bgjobs*(db: Db) =
  for fn in db.bgjobs: fn()

proc home*(db: Db): Option[tuple[space: Space, doc: Doc]] =
  # Page that will be shown as home page, any page marked with "home" tag
  for sid, space in db.spaces:
    for did, doc in space.docs:
      if "home-page" in doc.ntags:
        return (space, doc).some

template build_db_process_cb*(db): auto =
  let db_process = build_sync_timer(100, () => db.process)
  let db_bgjobs  = build_sync_timer(500, () => db.process_bgjobs)
  proc =
    db_process()
    db_bgjobs()

proc get*(db: Db, sid, did: string): Option[(Space, Doc)] =
  if sid in db.spaces:
    let space = db.spaces[sid]
    if did in space.docs:
      let doc = space.docs[did]
      return (space, doc).some