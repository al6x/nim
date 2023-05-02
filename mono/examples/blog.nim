import base, mono/core

# Model --------------------------------------------------------------------------------------------
type
  Post* = object
    id*:    string
    title*: string
    text*:  string

  Blog* = object
    posts*: seq[Post]

# Location -----------------------------------------------------------------------------------------
type LocationKind = enum posts, post, unknown
type Location = object
  case kind*: LocationKind
  of post:
    id:  string
  of posts:
    discard
  of unknown:
    url: Url

proc to_s*(l: Location): string =
  case l.kind
  of post:    ["posts", l.id].to_url.to_s
  of posts:   ["posts"].to_url.to_s
  of unknown: l.url.to_s

proc parse*(_: type[Location], u: Url): Location =
  if u.path.len == 2 and u.path[0] == "posts":
    Location(kind: post, id: u.path[1])
  elif u.path.len == 1 and u.path[0] == "posts":
    Location(kind: posts)
  else:
    Location(kind: unknown, url: u)

# PostView -----------------------------------------------------------------------------------------
type PostView* = ref object of Component
  post*: Post

proc set_attrs*(self: PostView, post: Post) =
  self.post = post

proc render*(self: PostView): HtmlElement =
  h".post".window_title(self.post.title).content:
    + h".post_title".text self.post.title
    + h".post_text".text self.post.text

# PostsView -----------------------------------------------------------------------------------------
type PostsView* = ref object of Component
  blog*: Blog

proc set_attrs*(self: PostsView, blog: Blog) =
  self.blog = blog

proc render*(self: PostsView): HtmlElement =
  h".post_items".window_title("Posts").content:
    for post in self.blog.posts:
      let location = Location(kind: LocationKind.post, id: post.id)
      + h"a.block".location(location).text(post.title)

# BlogView -----------------------------------------------------------------------------------------
type BlogView* = ref object of Component
  # location*: Url    # Feature: location on top-level Component binded to Browser location
  # title*:    string # Feature: title on top-level Component binded to Browser title
  blog*:     Blog
  location*: Location

proc set_attrs*(self: BlogView, blog: Blog, location = Location(kind: posts)) =
  self.blog = blog; self.location = location

# Feature: called on location event, there's always at least one location event for the initial url.
proc on_location*(self: BlogView, url: Url) =
  self.location = Location.parse url

proc render*(self: BlogView): HtmlElement =
  let posts_location = Location(kind: posts)
  h".blog":
    + h"a.block".location(posts_location).text("All Posts")
    case self.location.kind
    of posts:
      + self.h(PostsView, "posts", (blog: self.blog))
    of post:
      let id = self.location.id
      let post = self.blog.posts.fget_by(id, id).get
      + self.h(PostView, id, (post: post))
    of unknown:
      + self.h(PostsView, "posts", (blog: self.blog))
        # Feature: seting location explicitly
        .window_location posts_location

when is_main_module:
  import mono/http, std/os

  let page: AppPage = proc(meta, html: string): string =
    """
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            .block { display: block; }
          </style>
        </head>
        <body>

      {html}

      <script type="module">
        import { run } from "/assets/mono.js"
        run()
      </script>

        </body>
      </html>
    """.dedent.replace("{html}", html)

  let blog = Blog(posts: @[
    Post(id: "1", title: "Title 1", text: "Text 1"),
    Post(id: "2", title: "Title 2", text: "Text 2"),
    Post(id: "3", title: "Title 3", text: "Text 3"),
  ])

  proc build_app(url: Url): tuple[page: AppPage, app: App] =
    let blog_view = BlogView()
    blog_view.set_attrs(blog = blog)

    let app: App = proc(events: seq[InEvent], mono_id: string): seq[OutEvent] =
      blog_view.process(events, mono_id)

    (page, app)

  run_http_server(build_app, port = 2000)