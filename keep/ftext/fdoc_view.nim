import base, mono/core, std/osproc
import ../core/spacem, ./fdoc, ./ftext, ./helpers, ../ui/palette as pl

proc FSectionView(doc: FDoc, section: FSection): El =
  let edit = el(IconButton, (icon: "edit", title: "Edit")):
    it.on_click proc = open_editor(doc.location, section.line_n)
  el(NoteSection, (title: section.title, tags: section.tags, controls: @[edit]))

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
        for warn in doc.warns:
          el(Message, (text: warn, kind: MessageKind.warn))
        for section in doc.sections:
          unless section.title.is_empty:
            el(FSectionView, (doc: doc, section: section))

          # for
          # el(NoteTextBlock, (html: data.text_block1_html))
        # el(NoteSection, ()):
        #   el(NoteTextBlock, (html: data.text_block2_html, show_controls: true))
        # el(NoteSection, (title: "Additional consequences of those 3 main issues")):
        #   el(NoteListBlock, (html: data.list_block1_html, warns: @["Invalid tag #some", "Invalid link /some"]))

    it.right = els:
      el(RSection, ()):
        el(IconButton, (icon: "edit", title: "Edit")):
          it.on_click proc = open_editor(doc.location)
      #   el(RSection, ()):
      #     el(RSearchField, ())
      #   el(RFavorites, (links: data.links))
      #   el(RTags, (tags: data.tags))
      #   el(RSpaceInfo, (warns: @[("12 warns", "/warns")]))
      #   el(RBacklinks, (links: data.links))
      #   el(RSection, (title: "Other", closed: true))

  result.window_title doc.title


method render_doc*(doc: FDocHead, space: Space, parent: Component): El =
  parent.el(FDocView, fmt"{space.id}/{doc.id}", (space: space, doc: doc))


# el(LRLayout, ()):
  #   # it.window_title post.title
  #   el(".some"):
  #     it.text "some"
  #   # it.left = els:
  #   #   el(Note, (title: "About Forex", tags: data.note_tags)):
  #   #     el(NoteSection, ()):
  #   #       el(NoteTextBlock, (html: data.text_block1_html))
  #   #     el(NoteSection, ()):
  #   #       el(NoteTextBlock, (html: data.text_block2_html, show_controls: true))
  #   #     el(NoteSection, (title: "Additional consequences of those 3 main issues")):
  #   #       el(NoteListBlock, (html: data.list_block1_html, warns: @["Invalid tag #some", "Invalid link /some"]))

  #     # it.right = els:
  #     #   el(RSection, ()):
  #     #     el(IconButton, (icon: "edit"))
  #     #   el(RSection, ()):
  #     #     el(RSearchField, ())
  #     #   el(RFavorites, (links: data.links))
  #     #   el(RTags, (tags: data.tags))
  #     #   el(RSpaceInfo, (warns: @[("12 warns", "/warns")]))
  #     #   el(RBacklinks, (links: data.links))
  #     #   el(RSection, (title: "Other", closed: true))

# proc AppView*(post: Post): El =
#   el".post":
#     it.window_title post.title
#     el"a.block":
#       it.location posts_url()
#       it.text "All Posts"
#     el".post":
#       el".post_title":
#         it.text post.title
#       el".post_text":
#         it.text post.text

# # posts_view ---------------------------------------------------------------------------------------
# proc PostsView*(blog: Blog): El =
#   el".post_items":
#     it.window_title "Posts"
#     for post in blog.posts:
#       el"a.block":
#         it.location post_url(post.id)
#         it.text post.title

