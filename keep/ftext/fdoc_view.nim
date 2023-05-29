import base, mono/core, std/osproc
import ../core/spacem, ./fdoc_head, ftext/[core, render], ./helpers, ../ui/palette as pl

type FDocView* = ref object of Component
  space*: Space
  doc*:   FDocHead

proc set_attrs*(self: FDocView, space: Space, doc: FDocHead) =
  self.space = space; self.doc = doc

proc render*(self: FDocView): El =
  let head = self.doc; let fdoc = self.doc.doc

  let edit_title = edit_btn(fdoc.location)
  let edit_tags  = edit_btn(fdoc.location, fdoc.tags_line_n)

  let context: FContext = (head.doc, self.space.id, FHtmlConfig.init)

  result =
    el(PApp, ( # App
      title: fdoc.title, title_hint: fdoc.location, title_controls: @[edit_title],
      warns: fdoc.warns,
      tags: fdoc.tags.with_path(context), tags_controls: @[edit_tags]
    )):
      for section in fdoc.sections: # Sections
        unless section.title.is_empty:
          let edit_section = edit_btn(fdoc.location, section.raw.lines[0])
          el(PFSection, (section: section, context: context, controls: @[edit_section]))

        for blk in section.blocks: # Blocks
          let edit_blk = edit_btn(fdoc.location, blk.raw.lines[0])
          el(PFBlock, (blk: blk, context: context, controls: @[edit_blk]))

  result.window_title fdoc.title

method render_doc*(doc: FDocHead, space: Space, parent: Component): El =
  parent.el(FDocView, fmt"{space.id}/{doc.id}", (space: space, doc: doc))

method serve_asset*(doc: FDocHead, space: Space, asset_rpath: string): BinaryResponse =
  file_response asset_path(doc.doc, asset_rpath)