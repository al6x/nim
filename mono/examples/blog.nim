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

proc posts_url(): string =
  Location(kind: posts).to_s

proc post_url(id: string): string =
  Location(kind: post, id: id).to_s

# post_view ----------------------------------------------------------------------------------------
# Feature: fuctional component, for simple components function could be used
proc PostView*(post: Post): El =
  el".post":
    it.window_title post.title
    el"a.block":
      it.location posts_url()
      it.text "All Posts"
    el".post":
      el".post_title":
        it.text post.title
      el".post_text":
        it.text post.text

# posts_view ---------------------------------------------------------------------------------------
proc PostsView*(blog: Blog): El =
  el".post_items":
    it.window_title "Posts"
    for post in blog.posts:
      el"a.block":
        it.location post_url(post.id)
        it.text post.title


# BlogView -----------------------------------------------------------------------------------------
type BlogView* = ref object of Component
  blog*:     Blog
  location*: Location

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
    el(PostsView, (blog: self.blog)):
      # Feature: redirect, in case of invalid url , for example '/' changing it to '/posts'
      it.window_location(posts_url())

when is_main_module:
  import mono/http, std/os

  let page: AppPage = proc(root_el: JsonNode): string =
    """
      <!DOCTYPE html>
      <html>
        <head>
          <title>{title}</title>
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
    """.dedent
      # Feature: Setting title in initial HTML to improve SEO. Could be omited, as
      # it will be set automatically by JS.
      .replace("{title}", root_el.window_title.escape_html)
      .replace("{html}", root_el.to_html(comments = true))

  let blog = Blog(posts: @[
    Post(id: "1", title: "Title 1", text: "Text 1"),
    Post(id: "2", title: "Title 2", text: "Text 2"),
    Post(id: "3", title: "Title 3", text: "Text 3"),
  ])

  proc build_app(url: Url): tuple[page: AppPage, app: App] =
    let blog_view = BlogView(blog: blog)

    let app: App = proc(events: seq[InEvent], mono_id: string): seq[OutEvent] =
      blog_view.process(events, mono_id)

    (page, app)

  run_http_server(build_app, port = 2000)