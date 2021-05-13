#!/usr/bin/env nim c -r

import basem, asyncm, deques, urlm, logm, jsonm
from httpcore import nil
from asynchttpserver import nil
from asyncnet import nil

export urlm

type
  Message = ref object
    json:    string

  Client = ref object
    request:    asynchttpserver.Request

  CanSubscribe* = proc (url: Url, topics: seq[string]): Option[string]

  PubSub* = object
    id*: string

  PubSubImpl = ref object
    topics:            Table[string, HashSet[string]]
    clients:           Table[string, Client]
    client_queues:     Table[string, Deque[Message]]
    senders:           HashSet[string]
    # Queue may exist some time even if there's no client, waiting for client to reconnect
    last_seen_ms:      Table[string, Timer]
    # How long ago the client was last seen

    can_subscribe:     CanSubscribe

    max_queue_len:               int
    max_waiting_if_no_client_ms: int

var pubsubs: Table[string, PubSubImpl]

proc log(ps: PubSub): Log = Log.init("PubSub", ps.id)


# Message.init -------------------------------------------------------------------------------------
var message_id_counter = 0
proc init_message(topic: string, message: JsonNode): Message =
  let id = message_id_counter
  message_id_counter += 1

  var data = newJObject()
  data["id"]      = id.to_json
  data["topic"]   = topic.to_json
  data["message"] = message
  Message(json: data.to_s)

proc init_special_message(special: string): Message =
  Message(json: (special: special).to_json.to_s)


# gc -----------------------------------------------------------------------------------------------
proc publish_for_client(ps: PubSub, client_id: string, message: Message)

template is_alive_or_recently_dead(psl: PubSubImpl, client_id: string): bool =
  if client_id in psl.clients: true
  else:
    if client_id notin psl.last_seen_ms: psl.last_seen_ms[client_id] = timer_ms()
    psl.last_seen_ms[client_id]() <= psl.max_waiting_if_no_client_ms

proc gc(ps: PubSub): void =
  ps.log.info "gc"
  var psl = pubsubs[ps.id]

  # Deleting empty topics and old listeners
  for topic in to_seq(psl.topics.keys):
    # Deleting listeners
    for client_id in psl.topics[topic].to_seq:
      if not psl.is_alive_or_recently_dead(client_id):
        psl.topics[topic].excl client_id
    # Deleting empty topics
    if psl.topics[topic].is_empty: psl.topics.del topic

  # Deleting client queues
  for client_id in to_seq(psl.client_queues.keys):
    if not psl.is_alive_or_recently_dead(client_id): psl.client_queues.del client_id

  # Deleting last seen
  for client_id in to_seq(psl.last_seen_ms.keys):
    if not psl.is_alive_or_recently_dead(client_id): psl.last_seen_ms.del client_id

  # Checking max queue size, could be if client connection is too slow to consume messages in time
  for client_id, queue in psl.client_queues:
    while psl.client_queues[client_id].len > psl.max_queue_len:
      psl.client_queues[client_id].pop_first

  # Pinging, results will be processed with the next gc run
  let ping_msg = init_special_message("ping")
  for client_id in to_seq(psl.clients.keys): ps.publish_for_client(client_id, ping_msg)

proc start_gc(ps: PubSub): Future[void] {.async.} =
  while true:
    await sleep_async 5000
    ps.gc()


# PubSub.init --------------------------------------------------------------------------------------
proc init*(
  _: type[PubSub],
  can_subscribe:                CanSubscribe,
  id                          = "default",
  max_queue_len               = 20,
  max_waiting_if_no_client_ms = 5000
): PubSub =
  pubsubs[id] = PubSubImpl(
    can_subscribe: can_subscribe,
    max_queue_len: max_queue_len, max_waiting_if_no_client_ms: max_waiting_if_no_client_ms)
  result = PubSub(id: id)
  spawn_async start_gc(result)


proc terminate_connection(ps: PubSub, client_id: string) =
  var psl = pubsubs[ps.id]
  if client_id in psl.clients:
    ps.log.with((client_id: client_id)).info("terminating {client_id}")
    try: asyncnet.close(psl.clients[client_id].request.client) except: discard
    psl.clients.del client_id


# start_sender -------------------------------------------------------------------------------------
proc has_client_and_messages(psl: PubSubImpl, client_id: string): bool =
  (client_id in psl.clients) and (client_id in psl.client_queues) and (psl.client_queues[client_id].len > 0)

proc start_sender(ps: PubSub, client_id: string): Future[void] {.async.} =
  # Each client has its own message queue and async sender, sender is running only when there are
  # some messages to send.
  var psl = pubsubs[ps.id]
  try:
    ps.log.with((client_id: client_id)).info("sender started for {client_id}")
    while psl.has_client_and_messages(client_id):
      var queue = psl.client_queues[client_id]

      let client = psl.clients[client_id]
      let message = queue.peek_first
      ps.log.with((client_id: client_id)).info("sending to {client_id}")

      let formatted_message = fmt"data: {message.json}" & "\n\n"
      await asynchttpserver.respond(client.request, httpcore.Http200, formatted_message)

      # Queue may be changed by GC
      if client_id in psl.client_queues and psl.client_queues[client_id].peek_first == message:
        discard psl.client_queues[client_id].pop_first
  except Exception as e:
    ps.log.with((client_id: client_id)).warn("can't send to {client_id}")
    ps.terminate_connection client_id
  finally:
    psl.senders.excl client_id
    ps.log.with((client_id: client_id)).info("sender stopped for {client_id}")

proc start_sender_if_needed(ps: PubSub, client_id: string) =
  var psl = pubsubs[ps.id]
  if psl.has_client_and_messages(client_id):
    psl.senders.incl client_id
    spawn_async(ps.start_sender(client_id), check = false)


# publish ------------------------------------------------------------------------------------------
proc publish_for_client(ps: PubSub, client_id: string, message: Message) =
  var psl = pubsubs[ps.id]
  if client_id notin psl.client_queues: psl.client_queues[client_id] = initDeque[Message]()
  psl.client_queues[client_id].add_last message
  ps.start_sender_if_needed(client_id)

proc publish(ps: PubSub, topic: string, message: Message): void =
  var psl = pubsubs[ps.id]
  ps.log.with((topic: topic)).info "publish {topic}"
  if topic notin psl.topics: return
  for client_id in psl.topics[topic]:
    ps.publish_for_client(client_id, message)

proc publish*[T](ps: PubSub, topic: string, message: T): void =
  let jmessage = when message is JsonNode: message
  else:                                    message.to_json
  ps.publish(topic, init_message(topic, message))


# subscribe ----------------------------------------------------------------------------------------
proc subscribe*(ps: PubSub, client_id: string, topics: seq[string]): void =
  var psl = pubsubs[ps.id]
  if topics.is_empty: return
  ps.log.with((client_id: client_id, topics: topics.join(", "))).info "subscribe {client_id} to {topics}"
  for topic in topics:
    if topic notin psl.topics: psl.topics[topic] = initHashSet[string]()
    psl.topics[topic].incl client_id


# http_handler -------------------------------------------------------------------------------------
# /subscribe?user_token=xxx&session_token=yyy&topics=a,b,c
proc http_handler*(ps: PubSub, req: asynchttpserver.Request): Future[void] {.async.} =
  var psl = pubsubs[ps.id]
  try:
    # Parsing request params
    let url = Url.init req.url
    let raw_topics = url.query["topics", ""]
    let topics = if raw_topics == "": @[] else: raw_topics.split(",")

    let client_ido = psl.can_subscribe(url, topics)
    if client_ido.is_none:
      await asynchttpserver.respond(req, httpcore.Http400, "400 Not authorised")
      ps.log.with((url: url)).warn "not authorised {client_id}"
      return
    let client_id = client_ido.get

    # Connecting
    ps.log.with((client_id: client_id)).info "connecting {client_id}"

    # Connecting
    let headers = asynchttpserver.newHttpHeaders({
      "Content-Type":                "text/event-stream",
      "Cache-Control":               "no-cache",
      "Connection":                  "keep-alive",
      "Access-Control-Allow-Origin": "*",
      "Content-Length":              "" # To prevent AsyncHttpServer from adding content-length
    })
    await asynchttpserver.respond(req, httpcore.Http200, "200", headers)

    # Subscribing
    ps.subscribe(client_id, topics)
    ps.terminate_connection client_id
    psl.clients[client_id] = Client(request: req)
    ps.start_sender_if_needed(client_id)
  except Exception as e:
    try:
      await asynchttpserver.respond(req, httpcore.Http400, "400 Can't connect")
      asyncnet.close(req.client)
    except:
      discard
    ps.log.warn("can't connect", e)