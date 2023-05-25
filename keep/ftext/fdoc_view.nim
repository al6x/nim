import base, mono/core, std/osproc
import ../core/spacem, ./fdoc_head, ftext/core as _, ./helpers, ../ui/palette as pl, ./fblocks_views

type FDocView* = ref object of Component
  space*: Space
  doc*:   FDocHead

proc set_attrs*(self: FDocView, space: Space, doc: FDocHead) =
  self.space = space; self.doc = doc

proc render*(self: FDocView): El =
  let head = self.doc; let doc = self.doc.doc

  let edit_title = edit_btn(doc.location)
  let edit_tags  = edit_btn(doc.location, doc.tags_line_n)

  result = el(PApp, ( # App
    title: doc.title, title_hint: doc.location, title_controls: @[edit_title],
    warns: doc.warns,
    tags: doc.tags, tags_controls: @[edit_tags]
  )):
    # for warn in doc.warns: # Doc warns
    #   el(PMessage, (text: warn, kind: PMessageKind.warn))

    for section in doc.sections: # Sections
      unless section.title.is_empty:
        let edit_section = edit_btn(doc.location, section.line_n)
        el(PSection, (title: section.title, tags: section.tags, controls: @[edit_section]))

      for blk in section.blocks: # Blocks
        add_or_return blk.render_fblock(doc, self.space, parent = self)

  result.window_title doc.title

method render_doc*(doc: FDocHead, space: Space, parent: Component): El =
  parent.el(FDocView, fmt"{space.id}/{doc.id}", (space: space, doc: doc))

method serve_asset*(doc: FDocHead, space: Space, asset_rpath: string): BinaryResponse =
  file_response asset_path(doc.doc, asset_rpath)