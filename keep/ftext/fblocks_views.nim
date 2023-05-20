import base, mono/core, std/osproc
import ../core/spacem, ./fdoc, ./ftext, ./helpers, ../ui/palette as pl

# proc FBlockView(doc: FDoc, section: FSection, blk: FBlock): El =
#   let edit = el(IconButton, (icon: "edit", title: "Edit")):
#     it.on_click proc = open_editor(doc.location, section.line_n)
#   el(NoteSection, (title: section.title, tags: section.tags, controls: @[edit]))

method render_fblock*(self: FBlock, doc: FDoc, section: FSection, parent: Component): El {.base.} =
  # throw "not implemented"
  render text block xxx not implemented

# method render_fblock*(self: FTextBlock, doc: FDoc, section: FSection, parent: Component): El {.base.} =
#   FBlock
#   # parent.el(FDocView, fmt"{space.id}/{doc.id}", (space: space, doc: doc))