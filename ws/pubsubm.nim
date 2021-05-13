#!/usr/bin/env nim c -r

import basem, asyncm, deques, urlm, logm, jsonm
from httpcore import nil
from asynchttpserver import nil
from asyncnet import nil

export urlm


# PubSub -------------------------------------------------------------------------------------------
type PubSub* = object
  id*: string

proc init*(_: type[PubSub], id = "default"): PubSub =
  PubSub(id: id)

proc `$`*(ps: PubSub): string = ps.id
proc hash*(ps: PubSub): Hash = ps.id.hash
proc `==`*(a, b: PubSub): bool = a.id == b.id

proc log(ps: PubSub): Log = Log.init("PubSub", ps.id)


# PubSubImpl ---------------------------------------------------------------------------------------
type
  Message = ref object
    json: string

  Client = ref object
    user_id: string
    request: asynchttpserver.Request

  CanSubscribe* = proc (url: Url, topics: seq[string]): Option[tuple[user_id: string, session_id: string]]

  PubSubImpl = ref object
    topics:            Table[string, HashSet[string]]
    sessions:          Table[string, Client]
    client_queues:     Table[string, Deque[Message]]
    senders:           HashSet[string]
    # Queue may exist some time even if there's no client, waiting for client to reconnect
    last_seen_ms:      Table[string, Timer]
    # How long ago the client was last seen

    can_subscribe:     CanSubscribe

    max_queue_len:               int
    max_waiting_if_no_client_ms: int
    max_sessions_per_user:       int

var impls: Table[PubSub, PubSubImpl]


# impl ---------------------------------------------------------------------------------------------
proc start_gc(ps: PubSub): Future[void]

proc impl*(
  ps:            PubSub,
  can_subscribe: CanSubscribe,
  id             = "default",

  max_queue_len               = 20,
  max_waiting_if_no_client_ms = 5000,
  max_sessions_per_user       = 5
): void =
  impls[ps] = PubSubImpl(
    can_subscribe: can_subscribe, max_queue_len: max_queue_len,
    max_waiting_if_no_client_ms: max_waiting_if_no_client_ms, max_sessions_per_user: max_sessions_per_user)

  spawn_async start_gc(ps)

proc impl(ps: PubSub): PubSubImpl =
  if ps notin impls: throw fmt"pubsub '{ps}' not defined"
  impls[ps]


# Message ------------------------------------------------------------------------------------------
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
proc publish_for_client(ps: PubSub, session_id: string, message: Message)

template is_alive_or_recently_dead(impl: PubSubImpl, session_id: string): bool =
  if session_id in impl.sessions: true
  else:
    if session_id notin impl.last_seen_ms: impl.last_seen_ms[session_id] = timer_ms()
    impl.last_seen_ms[session_id]() <= impl.max_waiting_if_no_client_ms

proc gc(ps: PubSub): void =
  ps.log.debug "gc start"
  var impl = ps.impl

  # Deleting empty topics and old listeners
  for topic in to_seq(impl.topics.keys):
    # Deleting listeners
    for session_id in impl.topics[topic].to_seq:
      if not impl.is_alive_or_recently_dead(session_id):
        impl.topics[topic].excl session_id
        ps.log.with((session_id: session_id, topic: topic)).debug("unsubscribing {session_id} from {topic}")
    # Deleting empty topics
    if impl.topics[topic].is_empty: impl.topics.del topic

  # Deleting client queues
  for session_id in to_seq(impl.client_queues.keys):
    if not impl.is_alive_or_recently_dead(session_id): impl.client_queues.del session_id

  # Deleting last seen
  for session_id in to_seq(impl.last_seen_ms.keys):
    if not impl.is_alive_or_recently_dead(session_id): impl.last_seen_ms.del session_id

  # Checking max queue size, could be if client connection is too slow to consume messages in time
  for session_id, queue in impl.client_queues:
    var dropped = false
    while impl.client_queues[session_id].len > impl.max_queue_len:
      impl.client_queues[session_id].pop_first
      dropped = true
    if dropped: ps.log.with((session_id: session_id)).warn("{session_id} queue is too big, dropping messages")

  # Pinging, results will be processed with the next gc run
  let ping_msg = init_special_message("ping")
  for session_id in to_seq(impl.sessions.keys): ps.publish_for_client(session_id, ping_msg)

  ps.log
    .with((sessions_count: impl.sessions.len, topics_count: impl.topics.len, senders_count: impl.senders.len))
    .debug "gc finish sessions = {sessions_count} topics = {topics_count} senders = {senders_count}"

proc start_gc(ps: PubSub): Future[void] {.async.} =
  while true:
    await sleep_async 5000
    ps.gc()


# terminate_connection -----------------------------------------------------------------------------
proc terminate_connection(ps: PubSub, session_id: string) =
  var impl = ps.impl
  if session_id in impl.sessions:
    ps.log.with((session_id: session_id)).debug("terminating {session_id}")
    try: asyncnet.close(impl.sessions[session_id].request.client) except: discard
    impl.sessions.del session_id


# start_sender -------------------------------------------------------------------------------------
proc has_client_and_messages(impl: PubSubImpl, session_id: string): bool =
  (session_id in impl.sessions) and (session_id in impl.client_queues) and (impl.client_queues[session_id].len > 0)

proc start_sender(ps: PubSub, session_id: string): Future[void] {.async.} =
  # Each client has its own message queue and async sender, sender is running only when there are
  # some messages to send.
  var impl = ps.impl
  try:
    ps.log.with((session_id: session_id)).debug("sender started for {session_id}")
    while impl.has_client_and_messages(session_id):
      var queue = impl.client_queues[session_id]

      let client = impl.sessions[session_id]
      let message = queue.peek_first
      ps.log.with((session_id: session_id)).info("sending to {session_id}")

      let formatted_message = fmt"data: {message.json}" & "\n\n"
      await asynchttpserver.respond(client.request, httpcore.Http200, formatted_message)

      # Queue may be changed by GC
      if session_id in impl.client_queues and impl.client_queues[session_id].peek_first == message:
        discard impl.client_queues[session_id].pop_first
  except Exception as e:
    ps.log.with((session_id: session_id)).warn("can't send to {session_id}")
    ps.terminate_connection session_id
  finally:
    impl.senders.excl session_id
    ps.log.with((session_id: session_id)).debug("sender stopped for {session_id}")

proc start_sender_if_needed(ps: PubSub, session_id: string) =
  var impl = ps.impl
  if impl.has_client_and_messages(session_id):
    impl.senders.incl session_id
    spawn_async(ps.start_sender(session_id), check = false)


# publish ------------------------------------------------------------------------------------------
proc publish_for_client(ps: PubSub, session_id: string, message: Message) =
  var impl = ps.impl
  if session_id notin impl.client_queues: impl.client_queues[session_id] = initDeque[Message]()
  impl.client_queues[session_id].add_last message
  ps.start_sender_if_needed(session_id)

proc publish(ps: PubSub, topic: string, message: Message): void =
  var impl = ps.impl
  ps.log.with((topic: topic)).info "publish {topic}"
  if topic notin impl.topics: return
  for session_id in impl.topics[topic]:
    ps.publish_for_client(session_id, message)

proc publish*[T](ps: PubSub, topic: string, message: T): void =
  let jmessage = when message is JsonNode: message
  else:                                    message.to_json
  ps.publish(topic, init_message(topic, message))


# subscribe ----------------------------------------------------------------------------------------
proc subscribe*(ps: PubSub, session_id: string, topics: seq[string]): void =
  var impl = ps.impl
  if topics.is_empty: return
  ps.log.with((session_id: session_id, topics: topics.join(", "))).info "subscribe {session_id} to {topics}"
  for topic in topics:
    if topic notin impl.topics: impl.topics[topic] = initHashSet[string]()
    impl.topics[topic].incl session_id


# session_limit_not_exceeded -----------------------------------------------------------------------
proc session_limit_exceeded(impl: PubSubImpl, user_id, session_id: string): bool =
  var user_sessions = 0
  for _, client in impl.sessions:
    if client.user_id == user_id: user_sessions += 1

  if session_id notin impl.sessions: # not counting new session if it's the same, as it's reconnect
    user_sessions += 1

  user_sessions > impl.max_sessions_per_user


# http_handler -------------------------------------------------------------------------------------
# /subscribe?user_token=xxx&session_token=yyy&topics=a,b,c
proc http_handler*(ps: PubSub, req: asynchttpserver.Request): Future[void] {.async.} =
  var impl = ps.impl
  try:
    # Parsing request params
    let url = Url.init req.url
    let raw_topics = url.query["topics", ""]
    let topics = if raw_topics == "": @[] else: raw_topics.split(",")

    # Authorisation
    let user = impl.can_subscribe(url, topics)
    if user.is_none:
      await asynchttpserver.respond(req, httpcore.Http400, "400 Not authorised")
      ps.log.with((url: url)).warn "not authorised {url}"
      return
    let (session_id, user_id) = user.get

    # Checking user session limit
    if impl.session_limit_exceeded(user_id, session_id):
      await asynchttpserver.respond(req, httpcore.Http400, "400 Session limit exceeded")
      ps.log.with((user_id: user_id)).warn "session limit exceeded for {user_id}"
      return

    # Connecting
    ps.log.with((session_id: session_id)).info "connecting {session_id}"

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
    ps.subscribe(session_id, topics)
    ps.terminate_connection session_id
    impl.sessions[session_id] = Client(request: req)
    ps.start_sender_if_needed(session_id)
  except Exception as e:
    try:
      await asynchttpserver.respond(req, httpcore.Http400, "400 Can't connect")
      asyncnet.close(req.client)
    except:
      discard
    ps.log.warn("can't connect", e)