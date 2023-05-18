import base, mono/[core, http], std/os
import ./app_view, ./core/[spacem, dbm], ./ftext/[fdoc, fdoc_view]

db = Db.init

block:
  let kolo_dir = current_source_path().parent_dir.absolute_path
  let space = Space.init(id = "some")
  db.spaces[space.id] = space
  space.add_ftext_dir fmt"{kolo_dir}/ftext/test"

proc sync_process =
  discard

run_http_server(build_app_view, port = 2000, sync_process = sync_process)