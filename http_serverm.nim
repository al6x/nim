import system except find
import os, threadpool, asyncdispatch
from jester import nil
from httpcore import nil

import basem, logm, jsonm, rem, timem
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
  # format*:   Format
  params*:   Table[string, string]

proc `[]`*(req: Request, key: string): string =
  req.params[key]

proc `[]`*(req: Request, key: string, default: string): string =
  req.params[key, default]


# Response ----------------------------------------------------------------------------------------
type Response* = ref object
  code*:     int
  content*:  string
  redirect*: string
  headers*:  seq[tuple[key, value: string]]


# Handlers -----------------------------------------------------------------------------------------
type Handler* = proc (req: Request): Response {.gcsafe.}


# Route --------------------------------------------------------------------------------------------
type Route* = ref object
  pattern*: Regex
  methd*:   string
  handler*: Handler


# ServerConfig -------------------------------------------------------------------------------------
type ServerConfig* = ref object
  host*:           string
  port*:           int
  # default_format*: Format
  async_delay*:    int

func init*(
  _: type[ServerConfig],
  host           = "localhost",
  port           = 5000,
  # default_format = "json",
  async_delay    = 3
): ServerConfig =
  # default_format: default_format
  ServerConfig(host: host, port: port, async_delay: async_delay)


# Server -------------------------------------------------------------------------------------------
type Server* = ref object
  config*: ServerConfig
  jester*: jester.Jester
  routes*: Table[string, seq[Route]] # First prefix to speed up route matching

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
  re"(^/[a-z0-9]+)".parse1(pattern).get(() => fmt"route '{pattern}' should have prefix")

proc route*(server: var Server, methd: string, pattern: Regex, handler: Handler): void =
  let route_prefix = methd & ":" & pattern.pattern.route_prefix
  var list = server.routes[route_prefix, @[]]
  list.add(Route(
    methd:   methd,
    pattern: pattern,
    handler: handler
  ))
  if list.len > 20: log().warn("route matching could be slow")
  server.routes[route_prefix] = list

proc route*(server: var Server, methd: string, pattern: string, handler: Handler): void =
  route(server, methd, route_pattern_to_re(pattern), handler)

proc get*(server: var Server, pattern: string | Regex, handler: Handler): void =
  route(server, "get", pattern, handler)

proc post*(server: var Server, pattern: string | Regex, handler: Handler): void =
  route(server, "post", pattern, handler)


# process ------------------------------------------------------------------------------------------
proc process(server: Server, req: Request): Response {.gcsafe.} =
  let req_log = log()
    .with((`method`: req.methd, method4: req.methd.take(4).align_left(4), path: req.path))

  # Matching route
  let route_prefix = req.methd & ":" & req.path.route_prefix
  let routeo = server
    .routes[route_prefix, @[]]
    .find((route) => route.methd == req.methd and route.pattern =~ req.path)

  if routeo.is_none:
    if not ignore_request(req.path):
      req_log.with((time: Time.now)).error("{method4} '{path}' route not found")
    return Response(code: 404)
  let route = routeo.get

  # Preparing for processing
  var req = req
  req.init2(route.pattern)

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
proc init2(req: var Request, pattern: Regex): void = # , default_format: Format
  req.params = pattern.parse_named(req.path) & req.query
  # req.format = try:
  #   parse_format(req.params, req.headers, $default_format).to_format
  # except:
  #   default_format


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  var server = Server.init()

  server.get("/users/:name/profile", proc (req: Request): auto =
    Response(content: "ok " & $(req))
  )

  server.run


# Format -------------------------------------------------------------------------------------------
# type Format* = enum html_e, data_e, text_e

# converter to_format*(s: string): Format = parse_enum[Format](fmt"{s}_e")
# func `$`*(s: Format): string = (s.repr).replace(re"_e$", "")
