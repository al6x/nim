import system except find
import basem, logm, jsonm, rem, timem, randomm
import ./supportm, ./helpersm

import os, threadpool, asyncdispatch
from jester import nil
from httpcore import nil
from times as times import nil

{.experimental: "code_reordering".}

proc log(): Log = Log.init "HTTP"


# Request ------------------------------------------------------------------------------------------
type Request* = ref object
  ip*:            string
  methd*:         string
  headers*:       Table[string, seq[string]]
  cookies*:       Table[string, string]
  path*:          string
  query*:         Table[string, string]
  body*:          string
  format*:        string
  params*:        Table[string, string]
  session_token*: string
  user_token*:    string

proc `[]`*(req: Request, key: string): string =
  req.params[key]

proc `[]`*(req: Request, key: string, default: string): string =
  req.params[key, default]


# Response ----------------------------------------------------------------------------------------
type Response* = ref object
  code*:     int
  content*:  string
  headers*:  seq[tuple[key, value: string]]

proc init*(
  _: type[Response], code = 200, content = "", headers: seq[tuple[key, value: string]] = @[]
): Response =
  Response(code: code, content: content, headers: headers)

proc respond*(content: string): Response =
  Response.init(content = content, headers = @[("Content-Type", "text/html;charset=utf-8")])

proc redirect*(url: string): Response =
  Response.init(303, "Redirected to {url}", @[("Location", url)])


# ServerConfig -------------------------------------------------------------------------------------
type ServerConfig* = ref object
  host*:           string
  port*:           int
  async_delay*:    int         # Delay while async handlers waits for threadpool
  data_formats*:   seq[string] # Data format types, like ["json", "yaml", "toml"]
  default_format*: string
  show_errors*:    bool        # Show stack trace on the error page, it's handy in development,
                               # but should be disabledled in production

func init*(
  _: type[ServerConfig],
  host           = "localhost",
  port           = 5000,
  async_delay    = 3,
  data_formats   = @["json"],
  default_format = "html",
  show_errors    = true
): ServerConfig =
  ServerConfig(
    host: host, port: port, async_delay: async_delay,
    data_formats: data_formats, default_format: default_format,
    show_errors: show_errors
  )


# Handler, ApiHandler ------------------------------------------------------------------------------
type
  Handler* = proc(req: Request): Response {.gcsafe.}

  ApiHandler*[T] = proc(req: Request): T {.gcsafe.}

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
  re"(^/[a-z0-9]+)".parse1(pattern.replace(re"^\^", ""))
    .ensure(() => fmt"route '{pattern}' should have prefix")

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
  proc data_handler(req: Request): Response =
    let data: T = handler(req)
    data.format_as(req.format)

  server.data_routes.add(pattern, methd, data_handler)

proc add_data_route*[T](server: var Server, pattern: string, methd: string, handler: ApiHandler[T]): void =
  server.add_data_route(route_pattern_to_re(pattern), methd, handler)

proc get_data*[T](server: var Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route(pattern, "get", handler)

proc post_data*[T](server: var Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route(pattern, "post", handler)


# process ------------------------------------------------------------------------------------------
type format_type = enum html_e, data_e, other_e
proc process(server: Server, req: Request): Response {.gcsafe.} =
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
    .find((route) => route.methd == req.methd and route.pattern =~ normalized_path)

  if routeo.is_none:
    if not ignore_request(req.path):
      req_log.with((time: Time.now)).error("{method4} {path} route not found")
    return (
      case format_type
      of html_e:  Response.init(404, server.render_not_found_page("Route not found"))
      of data_e:  format_error_as("Route not found", req.format)
      of other_e: Response.init(404, "Route not found")
    )
  let route = routeo.get

  # Finishing request initialization
  if routeo.is_some:
    req.params = routeo.get.pattern.parse_named(req.path) & req.query

    req.user_token    = req.params["user_token",    req.cookies["user_token",    secure_random()]]
    req.session_token = req.params["session_token", secure_random()]

  # Processing
  let tic = timer_ms()
  req_log.with((time: Time.now)).info("{method4} {path}.{format} started")

  try:
    var response = route.handler(req)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .info("{method4} {path}.{format} finished, {duration_ms}ms")

    # Writing cookies
    if format_type == html_e:
      response.headers.set_cookie("user_token", req.user_token)

    response
  except CatchableError as e:
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .with(e)
      .error("{method4} {path}.{format} failed, {duration_ms}ms, {error}")

    let show_errors = server.config.show_errors
    case format_type
    of html_e:
      Response.init(500, server.render_error_page("Unexpected error", e))
    of data_e:
      if show_errors: format_error_as(e, req.format)
      else:           format_error_as("Unexpected error", req.format)
    of other_e:
      if show_errors: Response.init(500, fmt"{e.message}\n{e.get_stack_trace}".escape_html)
      else:           Response.init(500, "Unexpected error")


# run ----------------------------------------------------------------------------------------------
proc run*(server: Server): void =
  log()
    .with((host: server.config.host, port: server.config.port))
    .info "started on http://{host}:{port}"

  let jester_handler: jester.MatchProc = proc (jreq: jester.Request): Future[jester.ResponseData] =
    jester_handler(server, jreq)

  jester.register(server.jester, jester_handler)
  jester.serve(server.jester)


# jester_handler -----------------------------------------------------------------------------------
# Delegates work to thread pool
proc jester_handler(server: Server, jreq: jester.Request): Future[jester.ResponseData] {.async.} =
  block route:
    let req = Request.partial_init(jreq)

    # Spawning and waiting for the result
    var cresp = spawn server.process(req)
    while true:
      if cresp.is_ready: break
      await sleep_async(server.config.async_delay)
    let resp: Response = ^cresp

    # Responding
    jester.resp(
      httpcore.HttpCode(resp.code),
      resp.headers.map((t) => (key: t.key, val: t.value)),
      resp.content
    )

# init_jester --------------------------------------------------------------------------------------
proc init_jester(config: ServerConfig): jester.Jester =
  let settings = jester.new_settings(
    port      = Port(config.port),
    staticDir = getCurrentDir() / "public",
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


# error pages and format ---------------------------------------------------------------------------
method render_error_page*(server: Server, message: string, error: ref CatchableError): string  {.base.} =
  render_default_error_page(message, error, server.config.show_errors)

method render_not_found_page*(_: Server, message: string): string  {.base.} =
  render_default_not_found_page(message)

# Can't be defined as method because it somehow violate memory safety
proc format_as[T](data: T, format: string): Response =
  if format == "json": Response.init(200, data.to_json, @[("Content-Type", "application/json")])
  else:                Response.init(500, fmt"Error, invalid format '{format}'")

proc format_error_as(message: string, format: string): Response =
  if format == "json":
    Response.init(200, (is_error: true, message: message).to_json, @[("Content-Type", "application/json")])
  else:
    Response.init(500, fmt"Error, invalid format '{format}'")

proc format_error_as(error: ref CatchableError, format: string): Response =
  if format == "json":
    let content = (is_error: true, message: error.message, stack: error.get_stack_trace).to_json
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
    respond "hi"
  )

  server.run