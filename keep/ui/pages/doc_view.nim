import base, mono/[core, http]
import ../../model, ../../render/blocks, ../helpers, ../palette as pl, ../location, ../partials/query_input

type DocView* = ref object of Component
  doc*:          Doc
  set_location*: proc(l: Location)

proc render*(self: DocView): El =
  let (doc, space) = (self.doc, self.doc.space)
  let context = RenderContext.init(doc, space.id)

  let right = els:
    el(QueryInputWithRedirect, (set_location: self.set_location))
    el(Tags, ())

  let right_down = els:
    el(Warns, ())

  let view =
    el(PApp, ( # App
      title: doc.title, title_hint: doc.title_hint, title_controls: doc.edit_title_btn.to_seq,
      warns: doc.warns,
      tags: doc.tags.with_path(context), tags_controls: doc.edit_tags_btn.to_seq,
      right: right, right_down: right_down
    )):
      for blk in doc.blocks: # Blocks
        if blk of TitleBlock: continue
        el(PBlock, (blk: blk, context: context, controls: edit_btn(blk).to_seq))

  view.window_title doc.title
  view


method render_doc*(doc: Doc, parent: Component, set_location: proc(l: Location)): El {.base.} =
  parent.el(DocView, fmt"{doc.space.id}/{doc.id}", (doc: doc, set_location: set_location))

method serve_asset*(doc: Doc, asset_rpath: string): BinaryResponse {.base.} =
  file_response asset_path(doc, asset_rpath)