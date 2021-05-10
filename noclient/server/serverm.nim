import basem, logm, jsonm, rem, timem, randomm, envm
import ./supportm, ./helpersm

import os, asyncdispatch
from jester import nil
from httpcore import nil
from times as times import nil

export helpersm

{.experimental: "code_reordering".}

proc log(): Log = Log.init "HTTP"


# ServerConfig -------------------------------------------------------------------------------------
type ServerConfig* = ref object
  host*:           string
  port*:           int
  data_formats*:   seq[string] # Data format types, like ["json", "yaml", "toml"]
  default_format*: string
  show_errors*:    bool        # Show stack trace on the error page, it's handy in development,
                               # but should be disabledled in production

  assets_path*:       string      # Http prefix for assets, like `/assets`
  assets_file_paths*: seq[string]
  max_file_size*:     int         # Currently large files are not supported
  cache_assets*:      bool

proc init*(
  _: type[ServerConfig],
  host           = "localhost",
  port           = 5000,
  data_formats   = @["json"],
  default_format = "html",
  show_errors    = true,

  assets_path       = "/assets",
  assets_file_paths = new_seq[string](),
  max_file_size     = 10_000_000,                  # 10 Mb
  cache_assets      = env.is_production()
): ServerConfig =
  const script_dir = instantiation_info(full_paths = true).filename.parent_dir
  ServerConfig(
    host: host, port: port,
    data_formats: data_formats, default_format: default_format,
    show_errors: show_errors,
    assets_path: assets_path, assets_file_paths: assets_file_paths, max_file_size: max_file_size
  )


# Request ------------------------------------------------------------------------------------------
type Request* = ref object
  ip*:            string
  methd*:         string
  headers*:       Table[string, seq[string]]
  cookies*:       Table[string, string]
  path*:          string
  query*:         Table[string, string]
  body*:          string
  data*:          JsonNode

  format*:        string
  params*:        Table[string, string]
  session_token*: string
  user_token*:    string

proc get(req: Request, key: string, default: Option[string]): string =
  if   key in req.body:   req.data[key].get_str
  elif key in req.query:  req.query[key]
  elif key in req.params: req.params[key]
  elif default.is_some:   default.get
  else:                   throw fmt"no '{key}' key in request"

proc `[]`*(req: Request, key: string): string =
  req.get(key, string.none)

proc `[]`*(req: Request, key: string, default: string): string =
  req.get(key, default.some)


# Response ----------------------------------------------------------------------------------------
type Response* = ref object
  code*:     int
  content*:  string
  headers*:  seq[(string, string)]

proc init*(
  _: type[Response], code = 200, content = "", headers: openarray[(string, string)] = @[]
): Response =
  Response(code: code, content: content, headers: headers.to_seq)

proc init*(
  _: type[Response], data: (int, string, seq[(string, string)])
): Response =
  Response(code: data[0], content: data[1], headers: data[2])

proc respond*(content: string): Response =
  Response.init(content = content, headers = @[("Content-Type", "text/html;charset=utf-8")])

proc redirect*(url: string): Response =
  Response.init(303, fmt"Redirected to {url}", @[("Location", url)])


# Handler, ApiHandler ------------------------------------------------------------------------------
type
  Handler* = proc(req: Request): Response

  ApiHandler*[T] = proc(req: Request): T

# Route --------------------------------------------------------------------------------------------
type Route* = ref object
  pattern*: Regex
  methd*:   string
  handler*: Handler


# Server -------------------------------------------------------------------------------------------
type Server* = ref object of RootObj
  config*:      ServerConfig
  jester*:      jester.Jester
  routes*:      Table[string, seq[Route]] # First prefix to speed up route matching
  data_routes*: Table[string, seq[Route]] # First prefix to speed up route matching

proc init_jester(config: ServerConfig): jester.Jester

proc init*(_: type[Server], config: ServerConfig): Server =
  Server(
    config: config,
    jester: init_jester(config)
  )

proc init*(
  _: type[Server],
  host        = "localhost",
  port        = 5000
): Server =
  Server.init(ServerConfig.init(host = host, port = port))


# route --------------------------------------------------------------------------------------------
# route_prefix needed to speed up route matching
proc route_prefix(pattern: string): string =
  re"(^/[a-z0-9]+)".parse1(pattern.replace(re"^\^", "")).get("")
    # .ensure(() => fmt"route '{pattern}' should have prefix")

proc add(routes: var Table[string, seq[Route]], pattern: Regex, methd: string, handler: Handler): void =
  let route = Route(pattern: pattern, methd: methd, handler: handler)
  let route_prefix = methd & ":" & pattern.pattern.route_prefix
  var list = routes[route_prefix, @[]]
  list.add(route)
  if list.len > 20: log().warn("route matching could be slow")
  routes[route_prefix] = list

proc add_route*(server: var Server, pattern: Regex, methd: string, handler: Handler): void =
  server.routes.add(pattern, methd, handler)

proc add_route*(server: var Server, pattern: string, methd: string, handler: Handler): void =
  server.routes.add(route_pattern_to_re(pattern), methd, handler)


# get, post ----------------------------------------------------------------------------------------
proc get*(server: var Server, pattern: string | Regex, handler: Handler): void =
  server.add_route(pattern, "get", handler)

proc post*(server: var Server, pattern: string | Regex, handler: Handler): void =
  server.add_route(pattern, "post", handler)


# data_route ---------------------------------------------------------------------------------------
proc add_data_route*[T](server: var Server, pattern: Regex, methd: string, handler: ApiHandler[T]): void =
  let iserver = server
  proc data_handler(req: Request): Response =
    let data: T = handler(req)
    iserver.format_as(data, req.format)

  server.data_routes.add(pattern, methd, data_handler)

proc add_data_route*[T](server: var Server, pattern: string, methd: string, handler: ApiHandler[T]): void =
  server.add_data_route(route_pattern_to_re(pattern), methd, handler)

proc get_data*[T](server: var Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route(pattern, "get", handler)

proc post_data*[T](server: var Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route(pattern, "post", handler)


# action -------------------------------------------------------------------------------------------
proc action*[D](server: var Server, action: string, handler: ApiHandler[D]): void =
  server.add_data_route("/" & action, "post", handler)


# process ------------------------------------------------------------------------------------------
type format_type = enum html_e, data_e, other_e
proc process(server: Server, req: Request): Response =
  # Serving files
  let file_res = handle_assets_slow(
    path              = req.path,
    query             = req.query,
    assets_path       = server.config.assets_path,
    assets_file_paths = server.config.assets_file_paths,
    max_file_size     = server.config.max_file_size,
    cache_assets      = server.config.cache_assets
  )
  if file_res.is_present:
    return Response.init(file_res.get)

  # Detecting format
  req.format = parse_format(req.query, req.headers).get(server.config.default_format)
  let format_type =
    if   req.format in server.config.data_formats: data_e
    elif req.format in @["html"]:                  html_e
    else:                                          other_e

  let req_log = log()
    .with((`method`: req.methd, method4: req.methd.take(4).align_left(4), path: req.path, format: req.format))

  # Matching route
  let routes = if format_type == data_e: server.data_routes else: server.routes

  let route_prefix = req.methd & ":" & req.path.route_prefix

  let normalized_path = req.path.replace(re"/$", "")
  let routeo = routes[route_prefix, @[]]
    .fget((route) => route.methd == req.methd and route.pattern =~ normalized_path)

  let route = if routeo.is_some: routeo.get
  else:
    if not ignore_request(req.path):
      req_log.with((time: Time.now)).error("{method4} {path} route not found")
    return (
      case format_type
      of html_e:  Response.init(404, server.render_not_found_page("Route not found"))
      of data_e:  server.format_error_as("Route not found", req.format)
      of other_e: Response.init(404, "Route not found")
    )

  # Finishing request initialization
  req.params = routeo.get.pattern.parse_named(req.path) & req.query
  req.data   = try:
    (if req.format == "json" and req.body != "": req.body else: "{}").parse_json
  except:
    return Response.init(400, "Invalid JSON body")

  req.user_token    = req.params["user_token",    req.cookies["user_token", secure_random_token()]]
  req.session_token = req.params["session_token", secure_random_token()]

  # Processing
  let tic = timer_ms()
  req_log.with((time: Time.now)).info("{method4} {path} as {format} started")

  try:
    var response = route.handler(req)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .info("{method4} {path} as {format} finished, {duration_ms}ms")

    # Writing cookies
    if format_type == html_e:
      response.headers.set_cookie("user_token", req.user_token)

    response
  except Exception as e:
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .with(e)
      .error("{method4} {path} as {format} failed, {duration_ms}ms, {error}")

    let show_errors = server.config.show_errors
    case format_type
    of html_e:
      Response.init(500, server.render_error_page("Unexpected error", e))
    of data_e:
      if show_errors: server.format_error_as(e, req.format)
      else:           server.format_error_as("Unexpected error", req.format)
    of other_e:
      if show_errors: Response.init(500, fmt"{e.message}\n{e.get_stack_trace}".escape_html)
      else:           Response.init(500, "Unexpected error")


# run ----------------------------------------------------------------------------------------------
proc run*(server: Server): void =
  log()
    .with((host: server.config.host, port: server.config.port))
    .info "started on http://{host}:{port}"

  let jester_handler: jester.MatchProc = proc (jreq: jester.Request): Future[jester.ResponseData] =
    {.gcsafe.}:
      jester_handler(server, jreq)

  jester.register(server.jester, jester_handler)
  jester.serve(server.jester)


# jester_handler -----------------------------------------------------------------------------------
# Delegates work to thread pool
proc jester_handler(server: Server, jreq: jester.Request): Future[jester.ResponseData] {.async.} =
  block route:
    let req = Request.partial_init(jreq)
    var resp = server.process(req)
    jester.resp(httpcore.HttpCode(resp.code), resp.headers, resp.content)


# init_jester --------------------------------------------------------------------------------------
proc init_jester(config: ServerConfig): jester.Jester =
  let settings = jester.new_settings(
    port      = Port(config.port),
    # staticDir = "/alex/projects/nim/browser", # fmt"{get_current_dir()}/../browser",
    appName   = "",
    bindAddr  = config.host,
    reusePort = false,
    # futureErrorHandler: proc (fut: Future[void]) {.closure, gcsafe.} = nil
  )
  jester.init_jester(settings)


# Request.partial_init -----------------------------------------------------------------------------
proc partial_init(_: type[Request], jreq: jester.Request): Request =
  let path  = jester.path(jreq)
  let query = jester.params(jreq)

  result.new
  result.ip       = jester.ip(jreq)
  result.methd    = httpcore.to_s(jester.req_method(jreq)).to_lower
  result.headers  = jester.headers(jreq).table[]
  result.cookies  = jester.cookies(jreq)
  result.path     = path
  result.query    = query
  result.body     = jester.body(jreq)


# error pages and format ---------------------------------------------------------------------------
# Override to use different error pages and formats
method render_error_page*(server: Server, message: string, error: ref Exception): string  {.base.} =
  render_default_error_page(message, error, server.config.show_errors)

method render_not_found_page*(_: Server, message: string): string  {.base.} =
  render_default_not_found_page(message)

method format_as[T](_: Server, data: T, format: string): Response {.base.} =
  if format == "json": Response.init(200, data.to_json.to_s, @[("Content-Type", "application/json")])
  else:                Response.init(500, fmt"Error, invalid format '{format}'")

method format_error_as(_: Server, message: string, format: string): Response {.base.} =
  if format == "json":
    Response.init(200, (is_error: true, message: message).to_json.to_s, @[("Content-Type", "application/json")])
  else:
    Response.init(500, fmt"Error, invalid format '{format}'")

method format_error_as(_: Server, error: ref Exception, format: string): Response {.base.} =
  if format == "json":
    let content = (is_error: true, message: error.message, stack: error.get_stack_trace).to_json.to_s
    Response.init(200, content, @[("Content-Type", "application/json")])
  else:
    Response.init(500, fmt"Error, invalid format '{format}'")


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  var server = Server.init()

  server.get_data("/users/:name/profile", (req: Request) =>
    (name: req["name"], age: 20)
  )

  server.get("/users/:name/profile", proc(req: Request): auto =
    let name = req["name"]
    respond fmt"{name} profile"
  )

  server.run