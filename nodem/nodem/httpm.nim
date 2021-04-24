import asyncdispatch, options, strformat, ./supportm, re, sets, json
from asynchttpserver as asynchttp import nil
import httpcore

type HttpMessageHandler* = proc (message: string): Future[Option[string]]

let headers = asynchttp.new_http_headers({"Content-type": "application/json; charset=utf-8"})

proc error(req: asynchttp.Request, message: string): Future[void] =
  asynchttp.respond(req, Http500, $(%((is_error: true, message: message))), headers)

proc success(req: asynchttp.Request, message: string): Future[void] =
  asynchttp.respond(req, Http200, message, headers)

# receive_http -------------------------------------------------------------------------------------
proc receive_http*(
  url:       string,
  handler:   HttpMessageHandler,
  allow_get: seq[string]   = @[]
): Future[void] {.async.} =
  # Use as example and modify to your needs.
  # Funcion need to be specifically allowed as GET because of security reasons.

  let (scheme, host, port, path) = parse_url url
  if scheme != "http": throw "only HTTP supported"
  if path != "": throw "wrong path"

  var allow_get_set = allow_get.to_hash_set

  var server = asynchttp.new_async_http_server()
  proc cb(req: asynchttp.Request): Future[void] {.async, gcsafe.} =
    try:
      case req.reqMethod
      of HttpGet:
        let fname = req.url.path.replace(re"^/", "")
        if fname notin allow_get_set: await req.error("not allowed as GET")
        let args: seq[string] = @[]
        let message = $(%((fn: fname, args: args)))
        let reply = await handler(message)
        await req.success reply.get("{}")
      of HttpPost:
        let message = req.body
        let reply = await handler(message)
        await req.success reply.get("{}")
      else:
        await req.error "method not allowed"
    except Exception as e:
      await req.error e.msg

  await asynchttp.serve(server, Port(port), cb, host)


# test ---------------------------------------------------------------------------------------------
if is_main_module: # Testing http
  # curl http://localhost:8000/tick
  # curl http://localhost:8000/ping
  # curl --request POST --data ping http://localhost:8000

  proc receive(message: string): Future[Option[string]] {.async.} =
    case message
    of "ping": # Handles `call`, with reply
      echo "ping"
      return "pong".some
    of "tick":    # Hanldes `send`, without reply
      echo "tick"
    else:
      throw fmt"unknown message {message}"

  async_check receive_http("http://localhost:8000", receive)
  run_forever()
