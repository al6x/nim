import base, mono/core, std/osproc
import ./support, ../../model, ../../render/blocks, ../palette, ./location

proc init*(_: type[RenderContext], doc: Doc, space_id: string): RenderContext =
  proc asset_path_with_mono_id(path: string, context: RenderContext): string =
    Url.init(blocks.asset_path(path, context), { "mono_id": mono_id }).to_s
  let config = RenderConfig(link_path: blocks.link_path, tag_path: blocks.tag_path, render_tag: render_tag,
    asset_path: asset_path_with_mono_id)
  (doc, space_id, config)

proc open_editor*(location: string, line = 1) =
  let cmd = fmt"code -g {location}:{line}"
  session_log().with((cmd: cmd)).info "edit"
  let output = exec_cmd_ex(command = cmd)
  if output.exit_code != 0: throw fmt"Can't open editor: '{cmd}'"

proc edit_text_source_btn*(location: string, line_n = 1): El =
  alter_el(el(PIconButton, (icon: "edit", title: "Edit"))):
    it.on_click proc = open_editor(location, line_n)

template if_doc_with_text_source(source: DocSource, code) =
  if source of DocTextSource:
    let dsource {.inject.} = source.DocTextSource
    code

template if_block_with_text_source(source: BlockSource, code) =
  if source of BlockTextSource:
    let bsource {.inject.} = source.BlockTextSource
    code

proc title_hint*(doc: Doc): string =
  if_doc_with_text_source doc.source:
    return dsource.location

proc edit_title_btn*(doc: Doc): Option[El] =
  if_doc_with_text_source doc.source:
    return edit_text_source_btn(dsource.location).some

proc edit_tags_btn*(doc: Doc): Option[El] =
  if_doc_with_text_source doc.source:
    return edit_text_source_btn(dsource.location, dsource.tags_line_n[0]).some

proc edit_btn*(blk: Block): Option[El] =
  if_doc_with_text_source blk.doc.source:
    if_block_with_text_source blk.source:
      return edit_text_source_btn(dsource.location, bsource.line_n[0]).some

proc Warns*(): El =
  let warns_count = db.docs_with_warns_cached.len
  list_el:
    if warns_count > 0:
      let message = fmt"""{warns_count} {warns_count.pluralize("doc")} with warns"""
      el(PRBlock, (tname: "prblock-warnings")):
        el(PWarnings, (warns: @[(message, warns_url())]))

proc Tags*(): El =
  let tags = db.ntags_cached.keys.map(decode_tag).sortit(it.to_lower)
  el(PTags, ()):
    for tag in tags:
      alter_el(el(PTag, (text: tag))):
        it.attr("href", tag_url(tag))

type QueryInput* = ref object of Component
  # Complicated input, it needs to store query as string separately from the location, and also
  # it should update location when query string changed
  filter*:       Filter
  set_location*: proc(l: Location)
  query*:        string

proc after_create*(self: QueryInput) =
  self.query = self.filter.to_s # Setting the initial query from url

proc set_query*(self: QueryInput, q: string) =
  self.query  = q
  self.filter = Filter.parse(q)
  self.set_location(Location(kind: filter, filter: self.filter))

proc render*(self: QueryInput): El =
  alter_el el(PSearchField, ()):
    it.value self.query
    it.on_input proc (e: InputEvent) = self.set_query(e.value)
    # it.bind_to(self.query)