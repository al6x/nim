import basem, logm, jsonm, rem, timem, randomm, envm, urlm
import ./http_supportm, ./http_helpersm

import os, asyncdispatch
from jester import nil
from httpcore import nil
from times as times import nil

export http_helpersm

{.experimental: "code_reordering".}

proc log(): Log = Log.init "HTTP"


# ServerDefinition -------------------------------------------------------------------------------------
type ServerDefinition* = ref object
  host*:           string
  port*:           int
  catch_errors*:   bool           # In development it's easier to debug if server fails on error
  show_errors*:    bool           # Show stack trace on the error page, should be disabledled in production

  assets_path*:       string      # Http prefix for assets, like `/assets`
  assets_file_paths*: seq[string]
  max_file_size*:     int         # Currently large files are not supported
  cache_assets*:      bool

proc init*(
  _: type[ServerDefinition],
  host           = "localhost",
  port           = 8080,
  catch_errors   = env.is_production(),
  show_errors    = not env.is_production(),

  assets_path       = "/assets",
  assets_file_paths = new_seq[string](),
  max_file_size     = 10_000_000,                  # 10 Mb
  cache_assets      = env.is_production()
): ServerDefinition =
  ServerDefinition(
    host: host, port: port, show_errors: show_errors,
    assets_path: assets_path, assets_file_paths: assets_file_paths, max_file_size: max_file_size
  )


# Request ------------------------------------------------------------------------------------------
type Request* = ref object
  ip*:            string
  methd*:         string
  headers*:       Table[string, seq[string]]
  cookies*:       Table[string, string]
  host*:          string
  port*:          int
  path*:          string
  query*:         Table[string, string]
  body*:          string
  data*:          JsonNode

  # format*:        string
  params*:        Table[string, string] # path params merged with query
  session_token*: string
  user_token*:    string

proc get(req: Request, key: string, default: Option[string]): string =
  let is_in_data = not req.data.is_nil and req.data.kind == JObject and key in req.data
  if is_in_data:          req.data[key].get_str
  elif key in req.query:  req.query[key]
  elif key in req.params: req.params[key]
  elif default.is_some:   default.get
  else:
    throw fmt"no '{key}' key in request"

proc `[]`*(req: Request, key: string): string =
  req.get(key, string.none)

proc `[]`*(req: Request, key: string, default: string): string =
  req.get(key, default.some)


# Response -----------------------------------------------------------------------------------------
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

proc respond_data*(data: string): Response =
  Response.init(content = data, headers = @[("Content-Type", "application/json")])

proc respond_data*[D](data: D): Response =
  respond_data $(data.to_json)

proc redirect*(url: string): Response =
  Response.init(303, "Redirected to {url}", @[("Location", url)])


# Handler, ApiHandler ------------------------------------------------------------------------------
type
  Handler* = proc(req: Request): Response

  ApiHandler*[R] = proc(req: Request): R
  JApiHandler*   = proc(req: Request): JsonNode


# Server -------------------------------------------------------------------------------------------
type Server* = ref object of RootObj
  id*: string

proc `$`*(server: Server): string = server.id
proc hash*(server: Server): Hash = server.id.hash
proc `==`*(a, b: Server): bool = a.id == b.id

proc init*(_: type[Server], id = "default"): Server =
  Server(id: id)

# Definitions --------------------------------------------------------------------------------------
var servers_definitions:  Table[Server, ServerDefinition]

proc define*(server: Server, definition: ServerDefinition): void =
  servers_definitions[server] = definition

proc define*(
  server: Server,
  host    = "localhost",
  port    = 8080
): void =
  server.define ServerDefinition.init(host = host, port = port)

proc definition*(server: Server): ServerDefinition =
  if server notin servers_definitions: throw fmt"server '{server.id}' not defined"
  servers_definitions[server]


# Routes -------------------------------------------------------------------------------------------
# Prefixes to speed up route matching
var routes*:        Table[(Server, string, string), Handler]
#                         (server, method, path) -> Handler
var re_routes*:     Table[(Server, string, string), seq[(Regex,   Handler)]]
#                         (server, method, prefix) ->  [(pattern, Handler)]
var api_routes*:    Table[(Server, string, string),   JApiHandler]
#                         (server, method, path)   -> JApiHandler
var api_re_routes*: Table[(Server, string, string), seq[(Regex,   JApiHandler)]]
#                         (server, method, prefix) ->  [(pattern, JApiHandler)]


# route --------------------------------------------------------------------------------------------
proc add_route(server: Server, methd: string, pattern: string | Regex, handler: Handler): void =
  let route = pattern.prepare_route
  if route.is_pattern:
    let key = (server, methd, route.prefix)
    var list = re_routes[key, @[]]
    if list.findi((item) => item[0] == route.pattern).is_some: throw "route already exist"
    list.add((route.pattern, handler))
    if list.len > 20: log().warn(fmt"route matching for '{route.prefix}'/* could be slow")
    re_routes[key] = list
  else:
    let key = (server, methd, route.path)
    if key in routes: throw "route already exist"
    routes[key] = handler

# get, post ----------------------------------------------------------------------------------------
proc get*(server: Server, pattern: string | Regex, handler: Handler): void =
  server.add_route("get", pattern, handler)

proc post*(server: Server, pattern: string | Regex, handler: Handler): void =
  server.add_route("post", pattern, handler)


# data_route ---------------------------------------------------------------------------------------
proc add_data_route*[R](
  server: Server, methd: string, pattern: string | Regex, handler: ApiHandler[R]
): void =
  let jhandler = proc (req: Request): JsonNode = handler(req).to_json
  let route = pattern.prepare_route
  if route.is_pattern:
    let key = (server, methd, route.prefix)
    var list = api_re_routes[key, @[]]
    if list.findi((item) => item[0] == route.pattern).is_some: throw "route already exist"
    list.add((route.pattern, jhandler))
    if list.len > 20: log().warn(fmt"route matching for '{route.prefix}'/* could be slow")
    api_re_routes[key] = list
  else:
    let key = (server, methd, route.path)
    if key in routes: throw "route already exist"
    api_routes[key] = jhandler

proc get_data*[T](server: Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route("get", pattern, handler)

proc post_data*[T](server: Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route("post", pattern, handler)


# process_assets -----------------------------------------------------------------------------------
proc process_assets(server: Server, normalized_path: string, req: Request): Option[Response] =
  let d = server.definition
  handle_assets_slow(
    path              = normalized_path,
    query             = req.query,
    assets_path       = d.assets_path,
    assets_file_paths = d.assets_file_paths,
    max_file_size     = d.max_file_size,
    cache_assets      = d.cache_assets
  ).map((file_res) => Response.init(file_res))

proc parse_and_set_tokens(req: var Request): void =
  req.user_token    = req["user_token",    req.cookies["user_token",    secure_random_token()]]
  req.params.del "user_token"
  req.query.del  "user_token"

  req.session_token = req["session_token", req.cookies["session_token", secure_random_token()]]
  req.params.del "session_token"
  req.query.del  "session_token"


# process_html -------------------------------------------------------------------------------------
proc process_html(server: Server, normalized_path: string, req: Request): Option[Response] =
  let routeo = if (server, req.methd, normalized_path) in routes:
    let path_params = init_table[string, string]()
    (path_params, routes[(server, req.methd, normalized_path)]).some
  else:
    let prefix = normalized_path.route_prefix
    re_routes[(server, req.methd, prefix), @[]]
      .fget((route) => route[0] =~ normalized_path)
      .map((route) =>
        (route[0].parse_named(normalized_path), route[1])
      )

  if routeo.is_none: return Response.none

  let req_log = log()
    .with((`method`: req.methd, method4: req.methd.take(4).align_left(4), path: normalized_path))

  # Preparing route and finishing request initialization
  let (path_params, handler) = routeo.get

  var req = req
  req.params = path_params
  parse_and_set_tokens req

  # Processing
  let tic = timer_ms()
  req_log.with((time: Time.now)).info("{method4} {path} started")

  try:
    var response = handler(req)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .info("{method4} {path} finished, {duration_ms}ms")

    block:
      # Setting tokens only if it's not already set by the handler,
      # using domain for `user_token` to make it available for subdomains
      response.headers.set_permanent_cookie_if_not_set("user_token", req.user_token, server.definition.host)
      response.headers.set_session_cookie_if_not_set("session_token", req.session_token)

    response.some
  except Exception as e:
    if not server.definition.catch_errors: quit(e)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .with(e)
      .error("{method4} {path} failed, {duration_ms}ms, {error}")
    Response.init(500, server.render_error_page("Unexpected error", e)).some


# process_api --------------------------------------------------------------------------------------
proc process_api(server: Server, normalized_path: string, req: Request): Option[Response] =
  let routeo = if (server, req.methd, normalized_path) in api_routes:
    let path_params = init_table[string, string]()
    (path_params, api_routes[(server, req.methd, normalized_path)]).some
  else:
    let prefix = normalized_path.route_prefix
    api_re_routes[(server, req.methd, prefix), @[]]
      .fget((route) => route[0] =~ normalized_path)
      .map((route) =>
        (route[0].parse_named(normalized_path), route[1])
      )

  if routeo.is_none: return Response.none

  let req_log = log()
    .with((`method`: req.methd, method4: req.methd.take(4).align_left(4), path: normalized_path))

  # Preparing route and finishing request initialization
  let (path_params, handler) = routeo.get

  var req = req
  req.params = path_params
  req.data   = (if req.body != "": req.body else: "{}").parse_json
  parse_and_set_tokens req

  # Processing
  let tic = timer_ms()
  req_log.with((time: Time.now)).info("{method4} {path} started")

  try:
    var response = handler(req)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .info("{method4} {path} finished, {duration_ms}ms")
    respond_data(response).some
  except Exception as e:
    if not server.definition.catch_errors: quit(e)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .with(e)
      .error("{method4} {path} failed, {duration_ms}ms, {error}")
    let error = if server.definition.show_errors:
      (is_error: true, message: e.msg, stack: e.get_stack_trace).to_json.`$`
    else:
      (is_error: true, message: e.msg).to_json.`$`
    respond_data(error).some


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
  let d = server.definition
  log()
    .with((host: d.host, port: d.port))
    .info "started on http://{host}:{port}"

  let jester_handler: jester.MatchProc = proc (jreq: jester.Request): Future[jester.ResponseData] =
    {.gcsafe.}:
      jester_handler(server, jreq)

  var jserver = init_jester(d.host, d.port)

  jester.register(jserver, jester_handler)
  jester.serve(jserver)


# jester_handler -----------------------------------------------------------------------------------
proc jester_handler(server: Server, jreq: jester.Request): Future[jester.ResponseData] {.async.} =
  block route:
    let req = Request.partial_init(jreq)
    var resp = server.process(req)
    jester_resp_fixed(httpcore.HttpCode(resp.code), resp.headers, resp.content)

# init_jester --------------------------------------------------------------------------------------
proc init_jester(host: string, port: int): jester.Jester =
  let settings = jester.new_settings(
    port      = Port(port),
    # staticDir = "/alex/projects/nim/browser", # fmt"{get_current_dir()}/../browser",
    appName   = "",
    bindAddr  = host,
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
  result.host     = jester.host(jreq)
  result.port     = jester.port(jreq)
  result.methd    = httpcore.`$`(jester.req_method(jreq)).to_lower
  result.headers  = jester.headers(jreq).table[]
  result.cookies  = jester.cookies(jreq)
  result.path     = path
  result.query    = query
  result.body     = jester.body(jreq)


# error pages and format ---------------------------------------------------------------------------
# Override to use different error pages and formats
method render_error_page*(server: Server, message: string, error: ref Exception): string  {.base.} =
  render_default_error_page(message, error, server.definition.show_errors)

method render_not_found_page*(_: Server, message: string): string  {.base.} =
  render_default_not_found_page(message)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let server = Server.init

  # server.get("/api/users/:name/profile", (req: Request) =>
  #   (name: req["name"], age: 20)
  # )

  server.get("/", proc (req: Request): auto =
    respond "ok"
  )

  server.get_data("/api/users/:name/profile", (req: Request) =>
    (name: req["name"], age: 20)
  )

  server.get("/users/:name/profile", proc(req: Request): auto =
    let name = req["name"]
    respond fmt"Hi {name}"
  )

  server.define
  server.run