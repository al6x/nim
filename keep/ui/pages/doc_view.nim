import base, mono/[core, http]
import ../../model, ../../render/blocks, ../helpers, ../support, ../palette as pl, ../location, ../partials/query_input

type DocView* = ref object of Component
  doc*:          Doc
  set_location*: proc(l: Location)

proc render*(self: DocView): El =
  let doc = self.doc
  let context = RenderContext.init(doc.sid, mono_id)

  let right = els:
    el(QueryInputWithRedirect, (set_location: self.set_location))
    el(Tags, ())

  let right_down = els:
    el(Warns, ())

  let view =
    el(PApp, ( # App
      title: doc.title, title_hint: doc.title_hint, title_controls: doc.edit_title_btn.to_seq,
      warns: doc.warns,
      tags: doc.source.tags, tags_controls: doc.edit_tags_btn.to_seq,
      right: right, right_down: right_down
    )):
      for blk in doc.blocks: # Blocks
        if blk of TitleBlock: continue

        let content = render_block(blk, context)
        let tags = if blk.show_tags: blk.source.tags else: @[]
        let controls = edit_btn(blk, doc).to_seq
        el(PBlock, (tag: fmt"pblock-{blk.kind}", content: content, tags: tags, warns: blk.warns, controls: controls))

  view.window_title doc.title.get(doc.id)
  view

method render_page*(doc: Doc, parent: Component, set_location: proc(l: Location)): El =
  parent.get(DocView, fmt"{doc.sid}/{doc.id}", (doc: doc, set_location: set_location)).render

method serve_asset*(doc: Doc, asset_rpath: string): BinaryResponse {.base.} =
  file_response asset_path(doc, asset_rpath)