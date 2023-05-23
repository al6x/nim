import base, mono/core, std/osproc
import ../core/spacem, ./fdoc_head, ftext/html, ./helpers, ../ui/palette as pl, ../ui/location

# Base
method render_fblock*(self: FBlock, doc: FDoc, space: Space, parent: Component): El {.base.} =
  let text = fmt"No view for {self.kind} block"
  let edit = edit_btn(doc.location, self.line_n)
  el(PTextBlock, (html: text.escape_html, controls: @[], warns: @[text]))

# Text
method render_fblock*(self: FTextBlock, doc: FDoc, space: Space, parent: Component): El =
  let edit = edit_btn(doc.location, self.line_n)
  el(PTextBlock, (html: self.to_html(doc, space.id), controls: @[edit], warns: self.warns, tags: @[]))

# List
method render_fblock*(self: FListBlock, doc: FDoc, space: Space, parent: Component): El =
  let edit = edit_btn(doc.location, self.line_n)
  el(PListBlock, (html: self.to_html(doc, space.id), controls: @[edit], warns: self.warns, tags: @[]))

# Code
method render_fblock*(self: FCodeBlock, doc: FDoc, space: Space, parent: Component): El =
  let edit = edit_btn(doc.location, self.line_n)
  el(PCodeBlock, (code: self.code, controls: @[edit], warns: self.warns, tags: self.tags))

# Images
method render_fblock*(self: FImagesBlock, doc: FDoc, space: Space, parent: Component): El =
  let edit = edit_btn(doc.location, self.line_n)
  let images = self.images.map((path) => asset_url(space.id, doc.id, path))
  el(PImagesBlock, (images: images, controls: @[edit], warns: self.warns, tags: self.tags))