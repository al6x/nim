import system except find
import os, threadpool, asyncdispatch
from jester import nil
from httpcore import nil

import basem, logm, jsonm, rem, timem, jsonm
import http_server/supportm

{.experimental: "code_reordering".}

proc log(): Log = Log.init "HTTP"


# Request ------------------------------------------------------------------------------------------

type Request* = ref object
  ip*:       string
  methd*:    string
  headers*:  Table[string, seq[string]]
  cookies*:  Table[string, string]
  path*:     string
  query*:    Table[string, string]
  body*:     string
  format*:   string
  params*:   Table[string, string]

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
  Response.init(200, content, @[("Content-Type", "text/html;charset=utf-8")])

proc redirect*(url: string): Response =
  Response.init(303, "Redirected to {url}", @[("Location", url)])


# Handler, ApiHandler ------------------------------------------------------------------------------
type
  Handler* = proc(req: Request): Response {.gcsafe.}

  ApiHandler*[T] = proc(req: Request): T {.gcsafe.}

# Route --------------------------------------------------------------------------------------------
type Route* = ref object
  pattern*: Regex
  methd*:   string
  handler*: Handler


# ServerConfig -------------------------------------------------------------------------------------
type ServerConfig* = ref object
  host*:           string
  port*:           int
  async_delay*:    int         # Delay while async handlers waits for threadpool
  data_formats*:   seq[string] # Data format types, like ["json", "yaml", "toml"]
  default_format*: string

func init*(
  _: type[ServerConfig],
  host           = "localhost",
  port           = 5000,
  async_delay    = 3,
  data_formats   = @["json"],
  default_format = "html"
): ServerConfig =
  ServerConfig(
    host: host, port: port, async_delay: async_delay,
    data_formats: data_formats, default_format: default_format
  )


# Server -------------------------------------------------------------------------------------------
type Server* = ref object
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
    Response.init(200, $(data.to_json), @[("Content-Type", "application/json")])

  server.data_routes.add(pattern, methd, data_handler)

proc add_data_route*[T](server: var Server, pattern: string, methd: string, handler: ApiHandler[T]): void =
  server.add_data_route(route_pattern_to_re(pattern), methd, handler)

proc get_data*[T](server: var Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route(pattern, "get", handler)

proc post_data*[T](server: var Server, pattern: string | Regex, handler: ApiHandler[T]): void =
  server.add_data_route(pattern, "post", handler)


# process ------------------------------------------------------------------------------------------
proc process(server: Server, req: Request): Response {.gcsafe.} =
  let req_log = log()
    .with((`method`: req.methd, method4: req.methd.take(4).align_left(4), path: req.path))

  # Matching route
  let format = parse_format(req.query, req.headers).get(server.config.default_format)
  let routes = if format in server.config.data_formats: server.data_routes else: server.routes
  let route_prefix = req.methd & ":" & req.path.route_prefix
  let normalized_path = req.path.replace(re"/$", "")
  let routeo = routes[route_prefix, @[]]
    .find((route) => route.methd == req.methd and route.pattern =~ normalized_path)

  if routeo.is_none:
    if not ignore_request(req.path):
      req_log.with((time: Time.now)).error("{method4} '{path}' route not found")
    return Response(code: 404)
  let route = routeo.get

  # Preparing for processing
  var req = req
  req.init2(route.pattern, format)

  # Processing
  let tic = timer_ms()
  req_log.with((time: Time.now)).info("{method4} '{path}' started")

  try:
    let response = route.handler(req)
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .info("{method4} '{path}' finished, {duration_ms}ms")
    response
  except CatchableError as e:
    req_log
      .with((time: Time.now, duration_ms: tic()))
      .with(e)
      .error("{method4} '{path}' failed, {duration_ms}ms, {error}")
    Response(code: 500, content: "Unexpected error")


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
    let req = Request.init1(jreq)

    # Spawning and waiting for the result
    var cresp = spawn server.process(req)
    while true:
      if cresp.is_ready: break
      await sleep_async(server.config.async_delay)
    let resp: Response = ^cresp

    # Responding
    jester.resp2(
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


# Request.init -------------------------------------------------------------------------------------
# Initialization part 1
proc init1(_: type[Request], jreq: jester.Request): Request =
  let path  = jester.path(jreq)
  let query = jester.params(jreq)

  result.new
  result.ip       = jester.ip(jreq)
  result.methd    = httpcore.`$`(jester.req_method(jreq)).to_lower
  result.headers  = jester.headers(jreq).table[]
  result.cookies  = jester.cookies(jreq)
  result.path     = path
  result.query    = query

# Part 2
proc init2(req: var Request, pattern: Regex, format: string): void =
  req.params = pattern.parse_named(req.path) & req.query
  req.format = format


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



# Format -------------------------------------------------------------------------------------------
# type Format* = enum html_e, data_e, text_e

# converter to_format*(s: string): Format = parse_enum[Format](fmt"{s}_e")
# func `$`*(s: Format): string = (s.repr).replace(re"_e$", "")



# api_route2 ---------------------------------------------------------------------------------------
# proc api_route*[A, R](
#   server: var Server, methd: string, pattern: Regex, mapper: ApiMapper[A], handler: ApiHandler2[A, R]
# ): void =
#   proc api_handler(req: Request): Response {.gcsafe.} =
#     let arg:  A = mapper(req)
#     let data: R = handler(arg)
#     Response.init(200, $(data.to_json), @[("Content-Type", "application/json")])

#   server.route(methd, pattern, api_handler)

# proc api_route*[A, R](
#   server: var Server, methd: string, pattern: string, mapper: ApiMapper[A], handler: ApiHandler2[A, R]
# ): void =
#   api_route(server, methd, route_pattern_to_re(pattern), mapper, handler)

# proc api_get*[A, R](
#   server: var Server, pattern: string | Regex, mapper: ApiMapper[A], handler: ApiHandler2[A, R]
# ): void =
#   api_route(server, "get", pattern, mapper, handler)

# proc api_post*[A, R](
#   server: var Server, pattern: string | Regex, mapper: ApiMapper[A], handler: ApiHandler2[A, R]
# ): void =
#   api_route(server, "post", pattern, mapper, handler)