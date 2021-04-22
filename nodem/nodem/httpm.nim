import asyncdispatch, options, strformat, ./supportm, re
from asynchttpserver as asynchttp import nil
import httpcore

# on_receive ---------------------------------------------------------------------------------------
type HttpMessageHandler* = proc (message: string): Future[Option[string]]

proc on_receive_http*(url: string, handler: HttpMessageHandler): Future[void] {.async.} =
  # Use as example and modify to your needs

  let (scheme, host, port, path) = parse_url url
  if scheme != "http": throw "only HTTP supported"
  if path != "": throw "wrong path"

  var server = asynchttp.new_async_http_server()
  proc cb(req: asynchttp.Request): Future[void] {.async, gcsafe.} =
    let message = if req.reqMethod == HttpGet: req.url.path.replace(re"^/", "") else: req.body
    let reply = (await handler(message)).get("")
    let headers = {"Content-type": "application/json; charset=utf-8"}
    await asynchttp.respond(req, Http200, reply, asynchttp.new_http_headers(headers))

  await asynchttp.serve(server, Port(port), cb, host)


# test ---------------------------------------------------------------------------------------------
if is_main_module: # Testing http
  # curl http://localhost:8000/tick
  # curl http://localhost:8000/ping
  # curl --request POST --data ping http://localhost:8000

  proc on_receive(message: string): Future[Option[string]] {.async.} =
    case message
    of "ping": # Handles `call`, with reply
      echo "ping"
      return "pong".some
    of "tick":    # Hanldes `send`, without reply
      echo "tick"
    else:
      throw fmt"unknown message {message}"

  async_check on_receive_http("http://localhost:8000", on_receive)
  run_forever()
