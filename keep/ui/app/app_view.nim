import base, mono/[core, http], std/os
import ../../model/[spacem, dbm], ./location, ../palette, ./helpers, ./support
import ./doc_view, ./warns_view

type AppView* = ref object of Component
  location*: Location
  on_timer_db_version: Option[int]

proc on_location*(self: AppView, url: Url) =
  self.location = Location.parse url

proc render_doc(self: AppView, sid, did: string): El =
  let found = db.get(sid, did)
  if found.is_none: return el(PMessage, (text: "Not found", top: true))
  let (space, doc) = found.get
  doc.render_doc(space, parent = self)

proc render_doc(self: AppView, did: string): El =
  let found = db.get_doc(did)
  if found.is_none: return el(PMessage, (text: "Not found", top: true))
  let (space, doc) = found.get
  self.render_doc(space.id, did)

proc render_home(self: AppView): El =
  if db.config.home.is_some:
    self.render_doc(db.config.home.get)
  else:
    let text = "config.home not defined, set it to id of a page you want to be used as a home page"
    el(PMessage, (text: text, top: true))

proc render_search(self: AppView): El =
  el("", (text: "Search not impl"))

proc render_unknown(self: AppView): El =
  el("", (text: "Unknown not impl"))

proc render*(self: AppView): El =
  let l = self.location
  case l.kind
  of LocationKind.home: self.render_home
  of doc:               self.render_doc(l.sid, l.did)
  of shortcut:          self.render_doc(l.did)
  of LocationKind.find: self.render_search
  of warns:             self.el(WarnsView, ())
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