import base, mono/[core, http], std/os
import ../core/[spacem, dbm], ./location, ./palette

type AppView* = ref object of Component
  location*: Location
  on_timer_db_version: Option[int]

proc init*(_: type[AppView]): AppView =
  AppView()

proc set_attrs*(self: AppView) =
  discard

proc on_location*(self: AppView, url: Url) =
  self.location = Location.parse url

proc render_home(self: AppView): El =
  let h = db.home
  if h.is_none:
    el(Message, (text: "Home page not defined, add #home tag to any page you want to used as home page"))
  else:
    render_doc(h.get.doc, h.get.space, parent = self)

proc render_doc_helper(self: AppView, sid, did: string): El =
  if sid in db.spaces:
    let space = db.spaces[sid]
    if did in space.docs:
      let doc = space.docs[did]
      render_doc(doc, space, parent = self)
    else:
      el(Message, (text: fmt"Doc not found, {sid}/{did}"))
  else:
    el(Message, (text: fmt"Space not found, {sid}"))

proc render_search(self: AppView): El =
  el(""):
    it.text "Search not impl"

proc render_unknown(self: AppView): El =
  el(""):
    it.text "Unknown not impl"

proc render*(self: AppView): El =
  let l = self.location
  case l.kind
  of LocationKind.home: self.render_home
  of doc:               self.render_doc_helper(l.space, l.doc)
  of search:            self.render_search
  of unknown:           self.render_unknown

proc on_timer*(self: AppView): bool =
  if   self.on_timer_db_version.is_none:
    self.on_timer_db_version = db.version.some
    false
  elif self.on_timer_db_version == db.version:
    false
  else:
    self.on_timer_db_version = db.version.some
    true

let page: AppPage = proc(root_el: JsonNode): string =
  """
    <!DOCTYPE html>
    <html>
      <head>
        <title>{title}</title>
        <link rel="stylesheet" href="/assets/mono.css"/>
        <link rel="stylesheet" href="/assets/palette/build/palette.css"/>
      </head>
      <body>

    {html}

    <script type="module">
      import { run } from "/assets/mono.js"
      run()
    </script>

      </body>
    </html>
  """.dedent
    .replace("{title}", root_el.window_title.escape_html)
    .replace("{html}", root_el.to_html(comments = true))


proc build_app_view*(url: Url): tuple[page: AppPage, app: AppFn] =
  let app_view = AppView()

  let app_fn: AppFn = proc(events: seq[InEvent], mono_id: string): seq[OutEvent] =
    app_view.process(events, mono_id)

  (page, app_fn)

proc build_app_view_asset_paths*(): seq[string] =
  let dir = current_source_path().parent_dir.absolute_path
  @[fmt"{dir}/assets"]