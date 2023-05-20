import base, mono/core, std/osproc
import ../core/spacem, ./fdoc, ./ftext, ./helpers, ../ui/palette as pl, ./fblocks_views

proc FSectionView(doc: FDoc, section: FSection): El =
  let edit = el(IconButton, (icon: "edit", title: "Edit")):
    it.on_click proc = open_editor(doc.location, section.line_n)
  el(NoteSection, (title: section.title, tags: section.tags, controls: @[edit]))

  # kind*:     string
  #   id*:       string # If not set explicitly, will be hash of block's text
  #   args*:     string
  #   tags*:     seq[string]
  #   links*:    seq[(string, string)]
  #   glinks*:   seq[string]
  #   text*:     string
  #   line_n*:   int
  #   warns*:    seq[string]

type FDocView* = ref object of Component
  space*: Space
  doc*:   FDocHead

proc set_attrs*(self: FDocView, space: Space, doc: FDocHead) =
  self.space = space; self.doc = doc

proc render*(self: FDocView): El =
  let head = self.doc; let doc = self.doc.doc

  let edit_title = el(IconButton, (icon: "edit", title: "Edit")):
    it.on_click proc = open_editor(doc.location)
  let edit_tags = el(IconButton, (icon: "edit", title: "Edit")):
    it.on_click proc = open_editor(doc.location, doc.tags_line_n)

  result = el(LRLayout, ()):
    it.left = els:
      el(Note, (
        title: doc.title, location: doc.location, title_controls: @[edit_title],
        tags: doc.tags, tags_controls: @[edit_tags]
      )):
        for warn in doc.warns: # Doc warns
          el(Message, (text: warn, kind: MessageKind.warn))

        for section in doc.sections: # Sections
          unless section.title.is_empty:
            el(FSectionView, (doc: doc, section: section))

          for blk in section.blocks: # Blocks
            add_or_return blk.render_fblock(doc, section, parent = self)

  result.window_title doc.title


method render_doc*(doc: FDocHead, space: Space, parent: Component): El =
  parent.el(FDocView, fmt"{space.id}/{doc.id}", (space: space, doc: doc))