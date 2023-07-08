import base, ftext/parse, std/os

# Model
import ./model, ./model/load

let parsers = DocFileParsers()
parsers["ft"] = (path, sid) => Doc.read(path, sid = sid)

db = Db.init
block:
  let keep_dir = current_source_path().parent_dir.absolute_path
  let space = Space.init(id = "notes")
  db.spaces[space.id] = space
  add_dir db, space, parsers, fmt"/alex/notes"

# UI
import mono/[core, http], ext/async
import ./ui/support, ./ui/pages/app_view, ui/palette as _

palette = Palette.init

run_http_server(
  () => AppView(),
  port         = 8080,
  asset_paths  = app_view_asset_paths(),
  sync_process = build_db_process_cb(db)
)