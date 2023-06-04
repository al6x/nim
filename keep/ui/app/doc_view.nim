import base, mono/core
import ../../model/[docm, spacem], ../../render/blocks, ./helpers, ../palette as pl

type DocView* = ref object of Component
  space*: Space
  doc*:   Doc

proc set_attrs*(self: DocView, space: Space, doc: Doc) =
  self.space = space; self.doc = doc

proc render*(self: DocView): El =
  let (doc, space) = (self.doc, self.space)
  let context = RenderContext.init(doc, space.id)

  result =
    el(PApp, ( # App
      title: doc.title, title_hint: doc.title_hint, title_controls: doc.edit_title_btn.to_seq,
      warns: doc.warns,
      tags: doc.tags.with_path(context), tags_controls: doc.edit_tags_btn.to_seq
    )):
      for blk in doc.blocks: # Blocks
        el(PBlock, (blk: blk, context: context, controls: edit_btn(blk, doc).to_seq))

  result.window_title doc.title

method render_doc*(doc: Doc, space: Space, parent: Component): El {.base.} =
  parent.el(DocView, fmt"{space.id}/{doc.id}", (space: space, doc: doc))

method serve_asset*(doc: Doc, space: Space, asset_rpath: string): BinaryResponse {.base.} =
  file_response asset_path(doc, asset_rpath)