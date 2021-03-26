import system except find
import os, threadpool, strformat, asyncdispatch
from jester import nil
from httpcore import nil

import basem, logm, jsonm, rem
import http_server/helpersm

{.experimental: "code_reordering".}

let log = Log.init "HTTP"


# Request ------------------------------------------------------------------------------------------
type Request* = ref object
  ip*:              string
  `method`*:        string
  headers*:         Table[string, seq[string]]
  cookies*:         Table[string, string]
  path*:            string
  query*:           Table[string, string]
  body*:            string
  format*:          string
  path_params*:     Table[string, string]


# Response -----------------------------------------------------------------------------------------
type Response* = ref object
  status*: int
  body*:   string


# Handler ------------------------------------------------------------------------------------------
type Handler* = proc (req: Request): Response {.gcsafe.}

type Route* = ref object
  `method`*: string
  pattern*:  Regex
  handler*:  Handler


# ServerConfig -------------------------------------------------------------------------------------
type ServerConfig* = ref object
  host*:           string
  port*:           int
  default_format*: string
  async_delay*:    int

func init*(
  _: type[ServerConfig],
  host           = "localhost",
  port           = 5000,
  default_format = "json",
  async_delay    = 3
): ServerConfig =
  ServerConfig(host: host, port: port, async_delay: async_delay)


# Server -------------------------------------------------------------------------------------------
type Server* = ref object
  config*: ServerConfig
  jester*: jester.Jester
  routes*: seq[Route]

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
proc route*(server: var Server, `method`: string, pattern: Regex, handler: Handler): void =
  server.routes.add(Route(
    `method`: `method`,
    pattern:  pattern,
    handler:  handler
  ))

proc route*(server: var Server, `method`: string, pattern: string, handler: Handler): void =
  route(server, `method`, route_pattern_to_re(pattern), handler)

proc get*(server: var Server, pattern: string | Regex, handler: Handler): void =
  route(server, "get", pattern, handler)

proc post*(server: var Server, pattern: string | Regex, handler: Handler): void =
  route(server, "post", pattern, handler)


# process ------------------------------------------------------------------------------------------
proc process(server: Server, req: Request): Response =
  # Matching route
  # TODO 2 use more efficient route matching
  let routeo = server.routes.find((route) => route.`method` == req.`method` and route.pattern =~ req.path)
  if routeo.is_some:
    let route = routeo.get
    var req = req
    req.init2(route.pattern)
    route.handler(req)
  else:
    Response(body: "unknown route")


# run ----------------------------------------------------------------------------------------------
proc run*(server: Server): void =
  log
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
    let resp = ^cresp

    jester.resp(resp.body)

    # case jester.path_info(request)
    # of "/":
    #   let response = await process_async("something")
    #   jester.resp(response)
    # else:
    #   jester.resp(jester.Http404, "Not found!")


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
  result.`method` = httpcore.`$`(jester.req_method(jreq)).to_lower
  result.headers  = jester.headers(jreq).table[]
  result.cookies  = jester.cookies(jreq)
  result.path     = path
  result.query    = query

# Part 2
proc init2(req: var Request, pattern: Regex): void =
  req.path_params = pattern.parse_named(req.path)
  # result.format   = query.get("format", default_format)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  var server = Server.init()

  server.get("/users/:name/profile", proc (req: Request): auto =
    Response(body: "ok " & $(req))
  )

  server.run




# req.headers.getOrDefault("Content-Type")