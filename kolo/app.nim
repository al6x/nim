import base, mono/core
import ./palette, ./space, ./location

type App* = ref object of Component
  db*:       Db
  location*: Location

proc set_attrs*(self: App, db: Db) =
  self.db = db

proc on_location*(self: App, url: Url) =
  self.location = Location.parse url

proc render*(self: App): El =
  case self.location.kind
  of doc:
    el(""):
      it.text "doc"
    # let id = self.location.id
    # let post = self.blog.posts.fget_by(id, id).get
    # el(PostView, (post: post))
    # el(PostsView, (blog: self.blog))
  of search:
    el(""):
      it.text "search"
    # let id = self.location.id
    # let post = self.blog.posts.fget_by(id, id).get
    # el(PostView, (post: post))
  of unknown:
    el(""):
      it.text "unknown"
    # el(PostsView, (blog: self.blog)):
    #   # Feature: redirect, in case of invalid url , for example '/' changing it to '/posts'
    #   it.window_location(posts_url())

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
