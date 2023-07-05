import base, mono/[core, http], std/os
import ../../model, ../location, ../palette, ../helpers, ../support
import ./doc_view, ./warns_view, ./filter_view, ./search_view, ../partials/[query_input]

type AppView* = ref object of Component
  location*: Location
  on_timer_db_version: Option[int]

proc on_location*(self: AppView, url: Url) =
  self.location = Location.parse url

proc render_doc(self: AppView, sid, did: string): El =
  let doc = db.get(sid, did)
  if doc.is_none: return el(PMessage, (text: "Not found", top: true))
  proc set_location(l: Location) = self.location = l
  doc.get.render_doc(parent = self, set_location = set_location)

proc render_doc(self: AppView, did: string): El =
  let doc = db.get_doc(did)
  if doc.is_none: return el(PMessage, (text: "Not found", top: true))
  self.render_doc(doc.get.space.id, doc.get.id)

proc render_home(self: AppView): El =
  if db.config.home.is_some:
    self.render_doc(db.config.home.get)
  else:
    let text = "config.home not defined, set it to id of a page you want to be used as a home page"
    el(PMessage, (text: text, top: true))

proc render_filter(self: AppView, filter: Filter, page: int): El =
  proc set_location(l: Location) = self.location = l
  let query_input = self.get(QueryInput, (filter: filter, set_location: set_location))
  if filter.query.is_empty: el(FilterView, (query_input: query_input, page: page))
  else:                     el(SearchView, (query_input: query_input, page: page))

proc render_unknown(self: AppView): El =
  el("", (text: "Unknown page"))

proc render*(self: AppView): El =
  let l = self.location
  let el = case l.kind
  of LocationKind.home:   self.render_home
  of doc:                 self.render_doc(l.sid, l.did)
  of shortcut:            self.render_doc(l.did)
  of LocationKind.filter: self.render_filter(self.location.filter, self.location.page)
  of warns:               self.el(WarnsView, ())
  of unknown:             self.render_unknown
  of asset:               throw "asset should never happen in render"

  el.window_location self.location.to_url.to_s
  el

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
    let doc = db.get(l.sid, l.did)
    if doc.is_none:
      http_response(content = "Asset not found", code = 404)
    else:
      doc.get.serve_asset(l.asset)
  else:
    http_response "Invalid asset path", 400

proc page*(self: AppView, app_el: El): SafeHtml =
  default_html_page(app_el, styles = @["/assets/palette/build/palette.css"])

proc app_view_asset_paths*(): seq[string] =
  let keep_dir = current_source_path().parent_dir.parent_dir.parent_dir.absolute_path
  @[fmt"{keep_dir}/ui/assets"]