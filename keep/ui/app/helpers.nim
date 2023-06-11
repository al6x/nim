import base, mono/core, std/osproc
import ./support, ../../model, ../../render/blocks, ../palette

proc init*(_: type[RenderContext], doc: Doc, space_id: string): RenderContext =
  proc asset_path_with_mono_id(path: string, context: RenderContext): string =
    Url.init(blocks.asset_path(path, context), { "mono_id": mono_id }).to_s
  let config = RenderConfig(link_path: blocks.link_path, tag_path: blocks.tag_path,
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

proc edit_btn*(blk: Block, doc: Doc): Option[El] =
  if_doc_with_text_source doc.source:
    if_block_with_text_source blk.source:
      return edit_text_source_btn(dsource.location, bsource.line_n[0]).some