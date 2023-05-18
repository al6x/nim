import base, mono/[core, http], ext/async, std/os
import ./ui/app_view, ./core/[spacem, dbm], ui/palette as _
import ./ftext/[fdoc, fdoc_view]

palette = Palette.init
db = Db.init

block:
  let kolo_dir = current_source_path().parent_dir.absolute_path
  let space = Space.init(id = "some")
  db.spaces[space.id] = space
  space.add_ftext_dir fmt"{kolo_dir}/ftext/test"

run_http_server(
  build_app_view,
  port         = 2000,
  asset_paths  = build_app_view_asset_paths(),
  sync_process = build_db_process_cb(db)
)