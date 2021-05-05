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
  show_errors*:    bool        # Show stack trace on the error page, should be disabledled in production

  assets_path*:       string      # Http prefix for assets, like `/assets`
  assets_file_paths*: seq[string]
  max_file_size*:     int         # Currently large files are not supported
  cache_assets*:      bool

let is_production = env["environment", "development"] == "production"
proc init*(
  _: type[ServerConfig],
  host           = "localhost",
  port           = 8080,
  show_errors    = not is_production,

  assets_path       = "/assets",
  assets_file_paths = new_seq[string](),
  max_file_size     = 10_000_000,                  # 10 Mb
  cache_assets      = is_production
): ServerConfig =
  ServerConfig(
    host: host, port: port, show_errors: show_errors,
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

  # format*:        string
  params*:        Table[string, string] # path params merged with query
  session_token*: string
  user_token*:    string

proc get(req: Request, key: string, default: Option[string]): string =
  if not req.data.is_nil and req.data.kind == JObject and key in req.data:
    req.data[key].get_str
  elif key in req.params:
    req.params[key]
  elif default.is_some:
    default.get
  else:
    throw fmt"no '{key}' key in request"

proc `[]`*(req: Request, key: string): string =
  req.get(key, string.none)

proc `[]`*(req: Request, key: string, default: string): string =
  req.get(key, default.some)


# Response ----------------------------------------------------------------------------------------
type Response* = ref object
  code*:     int
  content*:  string
  headers*:  seq[(string, string)]

proc init*(_: type[Response], code = 200, content = "", headers: openarray[(string, string)] = @[]): Response =
  Response(code: code, content: content, headers: headers.to_seq)

proc init*(_: type[Response], data: (int, string, seq[(string, string)])): Response =
  Response(code: data[0], content: data[1], headers: data[2])

proc respond*(content: string): Response =
  Response.init(content = content, headers = @[("Content-Type", "text/html;charset=utf-8")])

proc redirect*(url: string): Response =
  Response.init(303, "Redirected to {url}", @[("Location", url)])


# Handler, ApiHandler ------------------------------------------------------------------------------
type
  Handler* = proc(req: Request): Response

  ApiHandler*[R] = proc(req: Request): R
  JApiHandler*   = proc(req: Request): JsonNode


# Server -------------------------------------------------------------------------------------------
type Server* = ref object of RootObj
  config*:        ServerConfig
  jester*:        jester.Jester
  # Prefixes to speed up route matching
  routes*:        Table[(string, string), Handler]                   # (method, path)   -> Handler
  re_routes*:     Table[(string, string), seq[(Regex, Handler)]]     # (method, prefix) -> [(pattern, Handler)]
  api_routes*:    Table[(string, string), JApiHandler]               # (method, path)   -> ApiHandler
  api_re_routes*: Table[(string, string), seq[(Regex, JApiHandler)]] # (method, prefix) -> [(pattern, Handler)]

proc init_jester(config: ServerConfig): jester.Jester

proc init*(_: type[Server], config: ServerConfig): Server =
  Server(config: config, jester: init_jester(config))

proc init*(
  _:   type[Server],
  host = "localhost",
  port = 8080
): Server =
  Server.init(ServerConfig.init(host = host, port = port))


# route --------------------------------------------------------------------------------------------
proc add_route(server: var Server, methd: string, pattern: string | Regex, handler: Handler): void =
  let route = pattern.prepare_route
  if route.is_pattern:
    let key = (methd, route.prefix)
    var list = server.re_routes[key, @[]]
    if list.findi((item) => item[0] == route.pattern).is_some: throw "route already exist"
    list.add((route.pattern, handler))
    if list.len > 20: log().warn(fmt"route matching for '{route.prefix}'/* could be slow")
    server.re_routes[key] = list
  else:
    let key = (methd, route.path)
    if key in server.routes: throw "route already exist"
    server.routes[key] = handler

# get, post ----------------------------------------------------------------------------------------
proc get*(server: var Server, pattern: string | Regex, handler: Handler): void =
  server.add_route("get", pattern, handler)

proc post*(server: var Server, pattern: string | Regex, handler: Handler): void =
  server.add_route("post", pattern, handler)


# data_route ---------------------------------------------------------------------------------------
proc add_data_route*[R](
  server: var Server, methd: string, pattern: string | Regex, handler: ApiHandler[R]
): void =
  let jhandler = proc (req: Request): JsonNode = %handler(req)
  let route = pattern.prepare_route
  if route.is_pattern:
    let key = (methd, route.prefix)
    var list = server.api_re_routes[key, @[]]
    if list.findi((item) => item[0] == route.pattern).is_some: throw "route already exist"
    list.add((route.pattern, jhandler))
    if list.len > 20: log().warn(fmt"route matching for '{route.prefix}'/* could be slow")
    server.api_re_routes[key] = list
  else:
    let key = (methd, route.path)
    if key in server.routes: throw "route already exist"
    server.api_routes[key] = jhandler

proc get_data*[T](server: var Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route("get", pattern, handler)

proc post_data*[T](server: var Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route("post", pattern, handler)


# process_assets -----------------------------------------------------------------------------------
proc process_assets(server: Server, normalized_path: string, req: Request): Option[Response] =
  handle_assets_slow(
    path              = normalized_path,
    query             = req.query,
    assets_path       = server.config.assets_path,
    assets_file_paths = server.config.assets_file_paths,
    max_file_size     = server.config.max_file_size,
    cache_assets      = server.config.cache_assets
  ).map((file_res) => Response.init(file_res))


# process_html -------------------------------------------------------------------------------------
proc process_html(server: Server, normalized_path: string, req: Request): Option[Response] =
  let routeo = if (req.methd, normalized_path) in server.routes:
    let path_params = init_table[string, string]()
    (path_params, server.routes[(req.methd, normalized_path)]).some
  else:
    let prefix = normalized_path.route_prefix
    server.re_routes[(req.methd, prefix), @[]]
      .fget((route) => route[0] =~ normalized_path)
      .map((route) =>
        (route[0].parse_named(normalized_path), route[1])
      )

  if routeo.is_none: return Response.none

  let req_log = log()
    .with((`method`: req.methd, method4: req.methd.take(4).align_left(4), path: normalized_path))

  # Preparing route and finishing request initialization
  let (path_params, handler) = routeo.get

  req.params        = path_params & req.query
  req.user_token    = req.params["user_token",    req.cookies["user_token",    secure_random_token()]]
  req.session_token = req.params["session_token", req.cookies["session_token", secure_random_token()]]

  # Processing
  let tic = timer_ms()
  req_log.with((time: Time.now)).info("{method4} {path} started")

  try:
    var response = handler(req)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .info("{method4} {path} finished, {duration_ms}ms")

    response.headers.set_permanent_cookie("user_token", req.user_token)
    response.headers.set_session_cookie("session_token", req.session_token)
    response.some
  except Exception as e:
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .with(e)
      .error("{method4} {path} failed, {duration_ms}ms, {error}")
    Response.init(500, server.render_error_page("Unexpected error", e)).some


# process_api --------------------------------------------------------------------------------------
proc process_api(server: Server, normalized_path: string, req: Request): Option[Response] =
  let routeo = if (req.methd, normalized_path) in server.api_routes:
    let path_params = init_table[string, string]()
    (path_params, server.api_routes[(req.methd, normalized_path)]).some
  else:
    let prefix = normalized_path.route_prefix
    server.api_re_routes[(req.methd, prefix), @[]]
      .fget((route) => route[0] =~ normalized_path)
      .map((route) =>
        (route[0].parse_named(normalized_path), route[1])
      )

  if routeo.is_none: return Response.none

  let req_log = log()
    .with((`method`: req.methd, method4: req.methd.take(4).align_left(4), path: normalized_path))

  # Preparing route and finishing request initialization
  let (path_params, handler) = routeo.get

  req.params        = path_params & req.query
  req.data          = (if req.body != "": req.body else: "{}").parse_json
  req.user_token    = req.params["user_token",    req.cookies["user_token",    secure_random_token()]]
  req.session_token = req.params["session_token", req.cookies["session_token", secure_random_token()]]

  # Processing
  let tic = timer_ms()
  req_log.with((time: Time.now)).info("{method4} {path} started")

  try:
    var response = handler(req)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .info("{method4} {path} finished, {duration_ms}ms")
    Response.init(200, $response, @[("Content-Type", "application/json")]).some
  except Exception as e:
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .with(e)
      .error("{method4} {path} failed, {duration_ms}ms, {error}")
    let error = if server.config.show_errors:
      (is_error: true, message: e.msg, stack: e.get_stack_trace).to_json
    else:
      (is_error: true, message: e.msg).to_json
    Response.init(200, error, @[("Content-Type", "application/json")]).some


# process ------------------------------------------------------------------------------------------
proc process(server: Server, req: Request): Response =
  let normalized_path =
    case req.path
    of "":  "/"
    of "/": "/"
    else:   req.path.replace(re"/$", "")

  var res = server.process_api(normalized_path, req)
  if res.is_some: return res.get

  res = server.process_html(normalized_path, req)
  if res.is_some: return res.get

  res = server.process_assets(normalized_path, req)
  if res.is_some: return res.get

  if not ignore_request(req.path):
    let req_log = log()
      .with((`method`: req.methd, method4: req.methd.take(4).align_left(4), path: normalized_path))
    req_log.with((time: Time.now)).error("{method4} {path} route not found")

  Response.init(404, server.render_not_found_page("Route not found"))


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
  result.methd    = httpcore.`$`(jester.req_method(jreq)).to_lower
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
  if format == "json": Response.init(200, data.to_json, @[("Content-Type", "application/json")])
  else:                Response.init(500, fmt"Error, invalid format '{format}'")

method format_error_as(_: Server, message: string, format: string): Response {.base.} =
  if format == "json":
    Response.init(200, (is_error: true, message: message).to_json, @[("Content-Type", "application/json")])
  else:
    Response.init(500, fmt"Error, invalid format '{format}'")

method format_error_as(_: Server, error: ref Exception, format: string): Response {.base.} =
  if format == "json":
    let content = (is_error: true, message: error.message, stack: error.get_stack_trace).to_json
    Response.init(200, content, @[("Content-Type", "application/json")])
  else:
    Response.init(500, fmt"Error, invalid format '{format}'")


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  var server = Server.init()

  server.get_data("/api/users/:name/profile", (req: Request) =>
    (name: req["name"], age: 20)
  )

  server.get("/users/:name/profile", proc(req: Request): auto =
    let name = req["name"]
    respond fmt"Hi {name}"
  )

  server.run