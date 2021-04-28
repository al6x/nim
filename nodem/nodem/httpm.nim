import strutils, strformat, options, uri, tables, hashes, sets, sugar, json
import asynchttpserver, httpclient, httpcore
from os import param_str
import ./nodem, ./supportm, ./asyncm, ./support_httpm

export nodem, asyncm


# call_async ---------------------------------------------------------------------------------------
proc call_async*(node: Node, message: string, timeout_ms: int): Future[string] {.async.} =
  if timeout_ms <= 0: throw "tiemout should be greather than zero"
  try:
    let client = new_async_http_client()
    let http_res = await post(client, node.definition.url, message).with_timeout(timeout_ms)
    if http_res.code != Http200:
      let body = await http_res.body
      throw(if body != "": body else: "unknown error")
    return await http_res.body
  except Exception as e:
    throw fmt"can't call {node}, {e.msg}"

proc call_async*(node: Node, message: string): Future[string] =
  node.call_async(message, node.definition.timeout_ms)


# call ---------------------------------------------------------------------------------------------
proc call*(node: Node, message: string, timeout_ms: int): string =
  # Send message and waits for reply
  try:
    wait_for node.call_async(message, timeout_ms)
  except Exception as e:
    # Cleaning messy async error
    throw fmt"can't call '{node}', {e.msg.clean_async_error}"

proc call*(node: Node, req: string): string =
  node.call(req, node.definition.timeout_ms)


# send_async ---------------------------------------------------------------------------------------
proc send_async*(node: Node, message: string, timeout_ms: int): Future[void] {.async.} =
  discard await node.call_async(message, timeout_ms)

proc send_async*(node: Node, message: string): Future[void] =
  node.send_async(message, node.definition.timeout_ms)


# send ---------------------------------------------------------------------------------------------
proc send*(node: Node, message: string, timeout_ms: int): void =
  discard node.call(message, timeout_ms)

proc send*(node: Node, message: string): void =
  node.send(message, node.definition.timeout_ms)


# receive_async ------------------------------------------------------------------------------------
type OnMessageAsync* = proc (message: string): Future[Option[string]]
type OnError*        = proc (e: ref Exception): void # mostly for logging

proc default_on_error(e: ref Exception): void = discard

proc run_http(node: Node, cb: proc (request: Request): Future[void] {.closure, gcsafe.}): Future[void] =
  let (scheme, host, port, path) = parse_url node.definition.url
  if scheme notin ["http", "https"]: throw "only http/https supported"
  if path != "": throw "wrong path"

  var server = new_async_http_server()
  return server.serve(Port(port), cb, host)

proc receive_async*(
  node:         Node,
  on_message:   OnMessageAsync,
  on_error:     OnError        = default_on_error,
  quit_on_error                = false             # in debug it's easier to quit on error
): Future[void] =
  proc cb(req: Request): Future[void] {.async, gcsafe.} =
    try:
      if req.req_method != HttpPost: throw "method not allowed"
      let reply = await on_message(req.body)
      await req.respond(Http200, reply.get(""))
    except Exception as e:
      if quit_on_error: quit(e)
      else:
        on_error(e)
        await req.respond(Http500, e.msg.clean_async_error)

  return node.run_http(cb)



# receive ------------------------------------------------------------------------------------------
type OnMessage* = proc (message: string): Option[string]

proc receive*(
  node:         Node,
  on_message:   OnMessage,
  on_error:     OnError    = default_on_error,
  quit_on_error            = false             # in debug it's easier to quit on error
): Future[void] =
  # Separate sync receive for better error messages, without async noise.
  #
  # While the handler itsel is sync, the messages received and send async, so there's no
  # waiting for networking.
  proc cb(req: Request): Future[void] {.gcsafe.} =
    try:
      if req.req_method != HttpPost: throw "method not allowed"
      let reply = on_message(req.body)
      return req.respond(Http200, reply.get(""))
    except Exception as e:
      if quit_on_error: quit(e)
      else:
        on_error(e)
        return req.respond(Http500, e.msg)

  return node.run_http(cb)


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


# # receive ------------------------------------------------------------------------------------------
# # const delay_ms = 100
# # proc receive*(node: Node): Future[string] {.async.} =
# #   # Auto-reconnects and waits untill it gets the message
# #   var success = false
# #   try:
# #     # Handling connection errors and auto-reconnecting
# #     while true:
# #       let socket = block:
# #         let (is_error, error, socket) = await connect node
# #         if is_error:
# #           await sleep_async delay_ms
# #           continue
# #         socket
# #       let (is_error, is_closed, error, _, message) = await socket.receive_message
# #       if is_error or is_closed:
# #         await sleep_async delay_ms
# #         continue
# #       success = true
# #       return message
# #   finally:
# #     # Closing socket on any error, it will be auto-reconnected
# #     if not success: await disconnect(node)


# # if is_main_module:
# #   # Clean error on server
# #   let server = Node("server")
# #   proc run_server =
# #     proc on_message(message: string): Option[string] =
# #       throw "some error"
# #     server.receive(on_message)

# #   proc run_client =
# #     server.send "some message"

# #   case param_str(1)
# #   of "server": run_server()
# #   of "client": run_client()
# #   else:        throw "unknown command"