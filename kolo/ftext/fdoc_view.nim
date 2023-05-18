import base, mono/core
import ../core/spacem, ./fdoc

type FDocView* = ref object of Component
  space*: Space
  doc*:   FDocHead

proc set_attrs*(self: FDocView, space: Space, doc: FDocHead) =
  self.space = space; self.doc = doc

proc render*(self: FDocView): El =
  el"":
    it.text self.doc.id
  # case self.location.kind
  # of posts:
  #   el(PostsView, (blog: self.blog))
  # of post:
  #   let id = self.location.id
  #   let post = self.blog.posts.fget_by(id, id).get
  #   el(PostView, (post: post))
  # of unknown:
  #   el(PostsView, (blog: self.blog)):
  #     # Feature: redirect, in case of invalid url , for example '/' changing it to '/posts'
  #     it.window_location(posts_url())

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

