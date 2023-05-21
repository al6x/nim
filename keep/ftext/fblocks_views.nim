import base, mono/core, std/osproc
import ../core/spacem, ./fdoc_head, ftext/[parse, to_html], ./helpers, ../ui/palette as pl

# Base
method render_fblock*(self: FBlock, doc: FDoc, section: FSection, parent: Component): El {.base.} =
  let text = fmt"No view for {self.kind} block"
  let edit = el(IconButton, (icon: "edit", title: "Edit")):
    it.on_click proc = open_editor(doc.location, self.line_n)
  el(NoteTextBlock, (html: text.escape_html, controls: @[edit], warns: @[text]))

# Text
method render_fblock*(self: FTextBlock, doc: FDoc, section: FSection, parent: Component): El =
  let edit = el(IconButton, (icon: "edit", title: "Edit")):
    it.on_click proc = open_editor(doc.location, self.line_n)
  el(NoteTextBlock, (html: self.to_html(doc), controls: @[edit], warns: self.warns))

# Code
method render_fblock*(self: FCodeBlock, doc: FDoc, section: FSection, parent: Component): El =
  let edit = el(IconButton, (icon: "edit", title: "Edit")):
    it.on_click proc = open_editor(doc.location, self.line_n)
  el(NoteCodeBlock, (code: self.code, controls: @[edit], warns: self.warns, tags: self.tags))