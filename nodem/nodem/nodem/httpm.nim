import strutils, strformat, options, tables, hashes, sets, sugar, json, re
import asynchttpserver, httpclient, httpcore
from os import param_str
import ./nodem, ./supportm, ./asyncm

export nodem, asyncm


# call_async ---------------------------------------------------------------------------------------
# var requests_pool: Table
proc call_async*(node: Node, message: string, timeout_ms: int, path = ""): Future[string] {.async.} =
  # path - additional path to merge into node base url
  if timeout_ms <= 0: throw "tiemout should be greather than zero"
  let url = if path != "": $(node.definition.parsed_url & Url.parse(path)) else: node.definition.url
  try:
    let client = new_async_http_client()
    let http_res = await post(client, url, message).with_timeout(timeout_ms)
    if http_res.code != Http200:
      let body = await http_res.body
      throw(if body != "": body else: "unknown error")
    return await http_res.body
  except Exception as e:
    throw fmt"can't call {node}, {e.msg}"

proc call_async*(node: Node, message: string, path = ""): Future[string] =
  node.call_async(message, node.definition.timeout_ms, path)


# call ---------------------------------------------------------------------------------------------
proc call*(node: Node, message: string, timeout_ms: int, path = ""): string =
  # Send message and waits for reply
  # path - additional path to merge into node base url
  try:
    wait_for node.call_async(message, timeout_ms)
  except Exception as e:
    # Cleaning messy async error
    throw fmt"can't call '{node}', {e.msg.clean_async_error}"

proc call*(node: Node, req: string, path = ""): string =
  node.call(req, node.definition.timeout_ms, path)


# send_async ---------------------------------------------------------------------------------------
proc send_async*(node: Node, message: string, timeout_ms: int, path = ""): Future[void] {.async.} =
  discard await node.call_async(message, timeout_ms, path)

proc send_async*(node: Node, message: string, path = ""): Future[void] =
  node.send_async(message, node.definition.timeout_ms, path)


# send ---------------------------------------------------------------------------------------------
proc send*(node: Node, message: string, timeout_ms: int, path = ""): void =
  discard node.call(message, timeout_ms, path)

proc send*(node: Node, message: string, path = ""): void =
  node.send(message, node.definition.timeout_ms, path)


# receive_async ------------------------------------------------------------------------------------
type OnMessageAsync* = proc (message: string  ): Future[Option[string]]
type OnError*        = proc (e: ref Exception): void # mostly for logging

proc default_on_error*(e: ref Exception): void = discard

var started_servers = Table[(string, int), (AsyncHttpServer, Future[void])]() # (host, port)
var routes: Table[(int, string), proc (req: Request): Future[void]] # (port, route) -> handler

proc add_route_and_start_server_if_not_started(
  url:   Url,
  route: proc (req: Request): Future[void]
): Future[void] =
  let base_path = url.path.replace(re"^/|/$", "")
  if "/" in base_path: throw fmt"slashes are not supported in base path '{base_path}'"
  if url.scheme notin ["http", "https"]: throw "only http/https supported"
  let (host, port) = (url.host, url.port)

  if (port, base_path) in routes: throw fmt"route '/{base_path}' already registered"
  routes[(port, base_path)] = route

  proc cb(req: Request): Future[void] {.gcsafe.} =
    let base_path = req.url.path.replace(re"^/|/$", "").replace(re"/.+", "")
    let handler =
      if (port, base_path)   in routes: routes[(port, base_path)]
      elif (port, "") in routes:        routes[(port, "")]
      else:
        let msg = fmt"route '/{base_path}' not found"
        return req.respond(Http500, msg)
    handler(req)

  let hp = (host, port)
  if hp notin started_servers:
    var server = new_async_http_server()
    started_servers[hp] = (server, server.serve(Port(port), cb, host))
  return started_servers[hp][1]

proc receive_async*(
  node:          Node,
  on_message:    OnMessageAsync,
  on_error:      OnError = default_on_error,
  catch_errors = true,                       # in debug it's easier to quit on error
  add_route =    add_route_and_start_server_if_not_started
): Future[void] =
  proc cb(req: Request): Future[void] {.async, gcsafe.} =
    try:
      if req.req_method != HttpPost: throw "method not allowed"
      let reply = await on_message(req.body)
      await req.respond(Http200, reply.get(""))
    except Exception as e:
      if catch_errors:
        on_error(e)
        await req.respond(Http500, e.msg.clean_async_error)
      else:
        quit(e)

  add_route(node.definition.parsed_url, cb)


# stop ---------------------------------------------------------------------------------------------
proc stop*(host: string, port: int): void =
  let hp = (host, port)
  if hp in started_servers:
    started_servers[hp][0].close
    started_servers.del hp


# receive_rest_async -------------------------------------------------------------------------------
type OnRestAsync* = proc (
  fname: string, positional: seq[string], named: Table[string, string], named_json: JsonNode
): Future[Option[string]]

proc receive_rest_async(
  url:            string,
  on_rest:        OnRestAsync,
  allow_get_bool: bool,
  allow_get_set:  HashSet[string],
  on_error:       OnError,
  catch_errors:   bool,

  add_route =     add_route_and_start_server_if_not_started
): Future[void] =
  # Use as example and modify to your needs.
  # Funcion need to be specifically allowed as GET because of security reasons.
  var url = Url.parse url
  let base_path = url.path.replace(re"/$", "")

  let headers = new_http_headers({"Content-type": "application/json; charset=utf-8"})

  proc cb(req: Request): Future[void] {.async, gcsafe.} =
    try:
      var parts = req.url.path.replace(base_path).replace(re"^/", "").split("/")
      let (fname, positional) = (parts[0], parts[1..^1])
      var named: Table[string, string]
      for k, v in req.url.query.decode_query: named[k] = v

      if req.req_method == HttpGet:
        if not (allow_get_bool or fname in allow_get_set):
          throw fmt"'{fname}' not allowed as GET"

      let named_json = if req.body == "": newJObject() else: req.body.parse_json

      let reply = await on_rest(fname, positional, named, named_json)
      await respond(req, Http200, reply.get("{}"), headers)
    except Exception as e:
      if catch_errors:
        on_error(e)
        await respond(req, Http500, $(%((is_error: true, message: e.msg))), headers)
      else:
        quit(e)

  add_route(url, cb)

proc receive_rest_async*(
  url:           string,
  on_rest:       OnRestAsync,
  allow_get:     seq[string] | bool = false, # GET disabled by default, for security reasons
  on_error:      OnError = default_on_error,
  catch_errors = false,                      # in debug it's easier to quit on error

  add_route =    add_route_and_start_server_if_not_started
): Future[void] =
  let (allow_get_bool, allow_get_set) = when allow_get is bool:
    (allow_get, init_hash_set[string]())
  else:
    (false, allow_get.to_hash_set)

  receive_rest_async(url, on_rest, allow_get_bool, allow_get_set, on_error, catch_errors, add_route)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  # Two nodes working simultaneously and exchanging messages, there's no client or server
  let (a, b) = (node"a", node"b")

  proc start(self: Node, other: Node) =
    proc log(msg: string) = echo fmt"node {self} {msg}"

    proc main: Future[void] {.async.} =
      for _ in 1..3:
        log "heartbeat"
        let dstate = await other.call_async("state")
        log fmt"state of other: {dstate}"
        await sleep_async 1000
      await other.send_async("quit")

    proc on_message(message: string): Future[Option[string]] {.async.} =
      case message
      of "state": # Handles `call`, with reply
        return fmt"{self} ok".some
      of "quit":    # Hanldes `send`, without reply
        log "quitting"
        quit()
      else:
        throw fmt"unknown message {message}"

    proc on_error(e: ref Exception): void = echo e.msg

    log "started"
    spawn_async main()
    spawn_async self.receive_async(on_message, on_error)

  start(a, b)
  start(b, a)
  run_forever()

# if is_main_module:
#   # Should print clean error on server
#   let server = Node("server")
#   proc run_server =
#     proc on_message(message: string): Option[string] =
#       throw "some error"
#     server.receive(on_message)

#   proc run_client =
#     server.send "some message"

#   case param_str(1)
#   of "server": run_server()
#   of "client": run_client()
#   else:        throw "unknown command"


# # receive ------------------------------------------------------------------------------------------
# type OnMessage* = proc (message: string): Option[string]

# proc receive*(
#   node:         Node,
#   on_message:   OnMessage,
#   on_error:     OnError    = default_on_error,
#   quit_on_error            = false             # in debug it's easier to quit on error
# ): Future[void] =
#   # Separate sync receive for better error messages, without async noise.
#   #
#   # While the handler itsel is sync, the messages received and send async, so there's no
#   # waiting for networking.
#   proc cb(req: Request): Future[void] {.gcsafe.} =
#     try:
#       if req.req_method != HttpPost: throw "method not allowed"
#       let reply = on_message(req.body)
#       return req.respond(Http200, reply.get(""))
#     except Exception as e:
#       if quit_on_error: quit(e)
#       else:
#         on_error(e)
#         return req.respond(Http500, e.msg)

#   var (_, _, _, path) = parse_url node.definition.url
#   path = path.replace(re"/$", "")
#   handlers[path] = cb
#   start_server_if_not_started(node.definition.url, on_error)