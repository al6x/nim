import asyncdispatch, options, strformat, strutils, sequtils, uri, re, sets, json
from asynchttpserver as asynchttp import nil
import httpcore
import ./supportm, ../nodem, ./http_support

# Parsers ------------------------------------------------------------------------------------------
proc from_string*(_: type[string], s: string): string = s
proc from_string*(_: type[int],    s: string): int    = s.parse_int
proc from_string*(_: type[float],  s: string): float  = s.parse_float
proc from_string*(_: type[bool],   s: string): bool   =
  case s.to_lower
  of "yes", "true", "t":  true
  of "no",  "false", "f": false
  else: throw fmt"invalid bool '{v}'"

proc from_string*[T](_: type[Option[T]], s: string): Option[T] =
  if s == "": T.none else: T.from_string(s).some

# proc from_string*(_: type[Time],   s: string): Time   = Time.init s
# proc from_string*[T](_: type[T], row: seq[string]): T =
#   var i = 0
#   for _, v in result.field_pairs:
#     v = from_string(typeof v, row[i])
#     i += 1

# Helpers ------------------------------------------------------------------------------------------

type HttpMessageHandler* = proc (message: string): Future[Option[string]]
type HttpMessageHandlerWithParser* = proc (fname: string, req: seq[string]): Future[Option[string]]

proc default_handler_wiht_parser(fname: string, req: seq[string]): Future[Option[string]] {.async.} =
  throw "not provided"

let headers = asynchttp.new_http_headers({"Content-type": "application/json; charset=utf-8"})

proc error(req: asynchttp.Request, message: string): Future[void] =
  asynchttp.respond(req, Http500, $(%((is_error: true, message: message))), headers)

proc success(req: asynchttp.Request, message: string): Future[void] =
  asynchttp.respond(req, Http200, message, headers)

# receive_http -------------------------------------------------------------------------------------
proc receive_http*(
  url:       string,
  allow_get: seq[string] = @[]
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
        var parts = req.url.path.replace(re"^/", "").split("/")
        let (fname, args_list) = (parts[0], parts[1..^1])
        var args_map: Table[string, string]
        for k, v in req.url.query.decode_query: args_map[k] = v
        if fname notin allow_get_set: await req.error("not allowed as GET")
        let reply = await nexport_handler_with_parser_async(fname, args_list, args_map)
        await req.success reply.get("{}")
      of HttpPost:
        let message = req.body
        let reply = await nexport_handler_async(message)
        await req.success reply.get("{}")
      else:
        await req.error "method not allowed"
    except Exception as e:
      await req.error e.msg

  await asynchttp.serve(server, Port(port), cb, host)


# test ---------------------------------------------------------------------------------------------
# if is_main_module: # Testing http
#   # curl http://localhost:8000/tick
#   # curl http://localhost:8000/ping
#   # curl --request POST --data ping http://localhost:8000

#   proc receive(message: string): Future[Option[string]] {.async.} =
#     case message
#     of "ping": # Handles `call`, with reply
#       echo "ping"
#       return "pong".some
#     of "tick":    # Hanldes `send`, without reply
#       echo "tick"
#     else:
#       throw fmt"unknown message {message}"

#   async_check receive_http("http://localhost:8000", receive)
#   run_forever()
