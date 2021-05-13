import basem, asyncm, timem, jsonm, ../pubsubm
from asynchttpserver import nil

# PubSub -------------------------------------------------------------------------------------------
let pubsub = PubSub.init


# Clock --------------------------------------------------------------------------------------------
proc publish_time(): Future[void] {.async.} =
  while true:
    pubsub.publish("time", Time.now.to_json)
    await sleep_async 1000

spawn_async publish_time


# PubSub impl --------------------------------------------------------------------------------------
proc can_subscribe(url: Url, topics: seq[string]): Option[string] =
  "1".some

pubsub.impl(can_subscribe = can_subscribe)

proc http_handler(req: asynchttpserver.Request): Future[void] {.gcsafe.} =
  pubsub.http_handler(req)

var server = asynchttpserver.new_async_http_server()
spawn_async asynchttpserver.serve(server, Port(5000), http_handler, "localhost")
run_forever()