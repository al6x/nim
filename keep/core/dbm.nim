import base, ext/vcache
import ./spacem

var db* {.threadvar.}: Db

proc init*(_: type[Db]): Db =
  Db()

proc version*(db: Db): int =
  var h: Hash
  for sid, space in db.spaces:
    h = h !& sid.hash !& space.version.hash
  !$h

proc process*(db: Db) =
  db.cache.cached("process(db)", db.version):
    for sid, space in db.spaces:
      space.validate_tags
      space.validate_links db
      for fn in space.processors: fn()

proc bgjobs*(db: Db) =
  for sid, space in db.spaces:
    for fn in space.bgjobs: fn()

proc home*(db: Db): Option[tuple[space: Space, doc: Doc]] =
  # Page that will be shown as home page, any page marked with "home" tag
  for sid, space in db.spaces:
    for did, doc in space.docs:
      if "home" in doc.tags:
        return (space, doc).some

template build_db_process_cb*(db): auto =
  let db_process = build_sync_timer(100, () => db.process)
  let db_bgjobs  = build_sync_timer(500, () => db.bgjobs)
  proc =
    db_process()
    db_bgjobs()