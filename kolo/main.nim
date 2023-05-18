import base, mono/[core, http], ext/async, std/os
import ./app_view, ./core/[spacem, dbm], ./ftext/[fdoc, fdoc_view]

db = Db.init
let db_process = build_sync_timer(100, () => db.process)
let db_bgjobs  = build_sync_timer(500, () => db.bgjobs)
proc sync_process =
  db_process()
  db_bgjobs()

block:
  let kolo_dir = current_source_path().parent_dir.absolute_path
  let space = Space.init(id = "some")
  db.spaces[space.id] = space
  space.add_ftext_dir fmt"{kolo_dir}/ftext/test"

run_http_server(build_app_view, port = 2000, sync_process = sync_process)