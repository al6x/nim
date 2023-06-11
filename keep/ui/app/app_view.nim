import base, mono/[core, http], std/os
import ../../model/[spacem, dbm], ./location, ../palette, ./helpers, ./support
import ./doc_view, ./warns_view

type AppView* = ref object of Component
  location*: Location
  on_timer_db_version: Option[int]

proc set_attrs*(self: AppView) =
  discard

proc on_location*(self: AppView, url: Url) =
  self.location = Location.parse url

proc render_home(self: AppView): El =
  let h = db.home
  if h.is_none:
    let text = "Home page not defined, add '#home-page' tag to any page you want to used as home page"
    el(PMessage, (text: text, top: true))
  else:
    render_doc(h.get.doc, h.get.space, parent = self)

proc render_doc_helper(self: AppView, sid, did: string): El =
  let found = db.get(sid, did)
  if found.is_none: return el(PMessage, (text: "Not found", top: true))
  let (space, doc) = found.get
  doc.render_doc(space, parent = self)

proc render_shortcut_helper(self: AppView, did: string): El =
  for _, space in db.spaces:
    if did in space.docs:
      return render_doc_helper(self, space.id, did)
  el(PMessage, (text: "Not found", top: true))

proc render_search(self: AppView): El =
  el("", (text: "Search not impl"))

proc render_unknown(self: AppView): El =
  el("", (text: "Unknown not impl"))

proc render*(self: AppView): El =
  let l = self.location
  case l.kind
  of LocationKind.home: self.render_home
  of doc:               self.render_doc_helper(l.sid, l.did)
  of shortcut:          self.render_shortcut_helper(l.did)
  of search:            self.render_search
  of warns:             el(WarnsView, ())
  of asset:             throw "asset should never happen in render"
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

proc on_binary*(self: AppView, url: Url): BinaryResponse =
  let l = Location.parse url
  if l.kind == asset:
    let found = db.get(l.sid, l.did)
    if found.is_none:
      http_response(content = "Asset not found", code = 404)
    else:
      let (space, doc) = found.get
      doc.serve_asset(space, l.asset)
  else:
    http_response "Invalid asset path", 400

proc page*(self: AppView, app_el: El): SafeHtml =
  default_html_page(app_el, styles = @["/assets/palette/build/palette.css"])

proc app_view_asset_paths*(): seq[string] =
  let keep_dir = current_source_path().parent_dir.parent_dir.parent_dir.absolute_path
  @[fmt"{keep_dir}/ui/assets"]