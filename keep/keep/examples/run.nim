import base, mono/[core, http], ext/async, std/os, ftext/parse
import ../ui/support, ../ui/pages/app_view, ../model/[spacem, dbm], ../ui/palette as _, ../model/load

let parsers = DocFileParsers()
parsers["ft"] = (path) => Doc.read path

palette = Palette.init
db = Db.init

block:
  let keep_dir = current_source_path().parent_dir.parent_dir.absolute_path
  let space = Space.init(id = "notes")
  db.spaces[space.id] = space
  add_dir db, space, parsers, fmt"{keep_dir}/examples/notes"

run_http_server(
  () => AppView(),
  port         = 8080,
  asset_paths  = app_view_asset_paths(),
  sync_process = build_db_process_cb(db)
)