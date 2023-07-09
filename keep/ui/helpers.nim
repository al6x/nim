import base, mono/core, std/osproc
import ./support, ../model, ../render/blocks, ./palette, ./location

# Polymorphic methods ------------------------------------------------------------------------------
method render_page*(record: Record, parent: Component, set_location: proc(l: Location)): El {.base.} =
  el(PMessage, (text: "render_page not defined for: " & record.kind, top: true))

method render_selected*(record: Record): El {.base.} =
  let content = build_el("", (text: record.text))
  let link = build_el(PIconLink, (icon: "link", url: record.url))
  el(PBlock, (tag: fmt"pblock-{record.kind}", content: content, tags: record.tags, warns: record.warns, controls: @[link], hover: false))

method render_selected*(blk: Block): El =
  let context = RenderContext.init(blk.sid, mono_id)
  let content = render_block(blk, context)
  let link = build_el(PIconLink, (icon: "link", url: blk.url))
  el(PBlock, (tag: fmt"pblock-{blk.kind}", content: content, tags: blk.tags, warns: blk.warns, controls: @[link], hover: false))

method render_selected*(doc: Doc): El =
  let content = build_el("", (text: doc.title.get(doc.id)))
  let link = build_el(PIconLink, (icon: "link", url: doc.url))
  el(PBlock, (tag: fmt"pblock-{doc.kind}", content: content, tags: doc.tags, warns: doc.warns, controls: @[link], hover: false))

method record_title*(record: Record): string {.base.} =
  record.id

method record_title*(blk: Block): string =
  blk.did

# Helpers ------------------------------------------------------------------------------------------
proc open_editor*(location: string, line = 1) =
  let cmd = fmt"code -g {location}:{line}"
  session_log().with((cmd: cmd)).info "edit"
  let output = exec_cmd_ex(command = cmd)
  if output.exit_code != 0: throw fmt"Can't open editor: '{cmd}'"

proc edit_text_source_btn*(location: string, line_n = 1): El =
  alter_el(el(PIconButton, (icon: "edit", title: "Edit"))):
    it.on_click proc = open_editor(location, line_n)

template if_doc_with_text_source(source: RecordSource, code) =
  if source of DocTextSource:
    let dsource {.inject.} = source.DocTextSource
    code

template if_block_with_text_source(source: RecordSource, code) =
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

proc edit_btn*(blk: Block, doc: Doc): Option[El] =
  if_doc_with_text_source doc.source:
    if_block_with_text_source blk.source:
      return edit_text_source_btn(dsource.location, bsource.line_n[0]).some

proc Warns*(): El =
  let warns_count = db.records_with_warns_cached.len
  list_el:
    if warns_count > 0:
      let message = fmt"""{warns_count} {warns_count.pluralize("doc")} with warns"""
      el(PRBlock, (tname: "prblock-warnings")):
        el(PWarnings, (warns: @[(message, warns_url())]))

proc Tags*(): El =
  let tags = db.tags_stats_cached
  el(PTags, ()):
    for tag in tags.keys.to_seq.sort:
      alter_el(el(PTag, (text: tag, title: tags[tag].to_s))):
        it.attr("href", tag_url(tag))