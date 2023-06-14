import base, mono/[core, http]
import ../../model, ../../render/blocks, ./helpers, ../palette as pl, ./location

type DocView* = ref object of Component
  space*: Space
  doc*:   Doc

proc render*(self: DocView): El =
  let (doc, space) = (self.doc, self.space)
  let context = RenderContext.init(doc, space.id)

  var right: seq[El]
  let all_tags = db.ntags_cached.keys
  right.add el(PTags, (tags: all_tags.with_path(context)))

  var right_down: seq[El]
  let warns_count = db.docs_with_warns_cached.len
  if warns_count > 0:
    let message = fmt"""{warns_count} {warns_count.pluralize("doc")} with warns"""
    right_down.add:
      el(PRBlock, (tname: "prblock-warnings")):
        el(PWarnings, (warns: @[(message, warns_url())]))

  let view =
    el(PApp, ( # App
      title: doc.title, title_hint: doc.title_hint, title_controls: doc.edit_title_btn.to_seq,
      warns: doc.warns,
      tags: doc.tags.with_path(context), tags_controls: doc.edit_tags_btn.to_seq,
      right: right, right_down: right_down
    )):
      for blk in doc.blocks: # Blocks
        el(PBlock, (blk: blk, context: context, controls: edit_btn(blk, doc).to_seq))

  view.window_title doc.title
  view


method render_doc*(doc: Doc, space: Space, parent: Component): El {.base.} =
  parent.el(DocView, fmt"{space.id}/{doc.id}", (space: space, doc: doc))

method serve_asset*(doc: Doc, space: Space, asset_rpath: string): BinaryResponse {.base.} =
  file_response asset_path(doc, asset_rpath)