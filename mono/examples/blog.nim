import base, mono/core

# Model --------------------------------------------------------------------------------------------
type
  Post* = object
    id*, title*, text*: string

  Blog* = object
    posts*: seq[Post]

# Location -----------------------------------------------------------------------------------------
type LocationKind = enum posts, post, unknown
type Location = object
  case kind*: LocationKind
  of post:    id: string
  of posts:   discard
  of unknown: url: Url

proc to_s*(l: Location): string =
  case l.kind
  of post:    ["posts", l.id].to_url.to_s
  of posts:   ["posts"].to_url.to_s
  of unknown: l.url.to_s

proc parse*(_: type[Location], u: Url): Location =
  if   u.path.len == 2 and u.path[0] == "posts": Location(kind: post, id: u.path[1])
  elif u.path.len == 1 and u.path[0] == "posts": Location(kind: posts)
  else:                                          Location(kind: unknown, url: u)

proc posts_url(): string =          Location(kind: posts).to_s
proc post_url(id: string): string = Location(kind: post, id: id).to_s

# post_view ----------------------------------------------------------------------------------------
# Feature: fuctional component, for simple components function could be used
proc PostView*(post: Post): El =
  el("post-view.block", (window_title: post.title)):
    el("a.block", (href: posts_url(), text: "All Posts"))
    el"post.block":
      el("post-title.block", (text: post.title))
      el("post-text.block", (text: post.text))

# posts_view ---------------------------------------------------------------------------------------
proc PostsView*(blog: Blog): El =
  el("posts-view.block", (window_title: "Posts")):
    for post in blog.posts:
      el("a.block", (href: post_url(post.id), text: post.title))

# BlogView -----------------------------------------------------------------------------------------
type BlogView* = ref object of Component
  blog*:     Blog
  location*: Location

proc set_attrs*(self: BlogView, blog: Blog) =
  self.blog = blog

# Feature: called on location event, there's always at least one location event for the initial url.
proc on_location*(self: BlogView, url: Url) =
  self.location = Location.parse url

proc render*(self: BlogView): El =
  case self.location.kind
  of posts:
    el(PostsView, (blog: self.blog))
  of post:
    let id = self.location.id
    let post = self.blog.posts.fget_by(id, id).get
    el(PostView, (post: post))
  of unknown:
    let e = el(PostsView, (blog: self.blog))
    # Feature: redirect, in case of invalid url , for example '/' changing it to '/posts'
    e.window_location(posts_url())
    e

# Deployment ---------------------------------------------------------------------------------------
when is_main_module:
  import mono/http

  proc page*(self: BlogView, app_el: El): SafeHtml =
    default_html_page(app_el, styles = @[".block { display: block; }"])

  define_session BlogSession, BlogView

  let blog = Blog(posts: @[
    Post(id: "1", title: "Title 1", text: "Text 1"),
    Post(id: "2", title: "Title 2", text: "Text 2"),
    Post(id: "3", title: "Title 3", text: "Text 3"),
  ])

  proc build_session(url: Url): Session =
    let app = BlogView()
    app.set_attrs(blog = blog)
    BlogSession.init app

  run_http_server(build_session, port = 2000)