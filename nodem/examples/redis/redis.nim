import nodem, nodem/httpm, options, sugar, sequtils, strformat
{.experimental: "code_reordering".}

type RedisNode* = ref object of Node
proc redis_node(id: string): RedisNode = RedisNode(id: id)

# Counters ------------------------------------------------
var counters: CountTable[string]
proc inc_counter*(_: RedisNode, counter: string): void {.nexport.} =
  counters.inc counter

proc get_counter*(_: RedisNode, counter: string): int {.nexport.} =
  counters[counter]

proc del_counter*(_: RedisNode, counter: string): void {.nexport.} =
  counters.del counter


# K/V store -----------------------------------------------
var kvstore: Table[string, string]
proc get*(_: RedisNode, k: string): Option[string] {.nexport.} =
  if k in kvstore: kvstore[k].some else: string.none

proc set*(_: RedisNode, k: string, v: string): void {.nexport.} =
  kvstore[k] = v


# Pub/Sub -------------------------------------------------
var last_messages: Table[string, string]    # topic -> message
var subscribers:   Table[string, seq[Node]] # topic -> subscribers
var notify_queue:  Table[Node, seq[string]] # subscriber -> updated topics
var running_notifiers: seq[Node]

proc subscribe*(_: RedisNode, listener: Node, topic: string): void {.nexport.} =
  if topic notin subscribers: subscribers[topic] = @[]
  if listener notin subscribers[topic]: subscribers[topic].add listener
  log fmt"{listener} subscribed to {topic}"

proc unsubscribe*(_: RedisNode, listener: Node, topic: string): void {.nexport.} =
  if topic notin subscribers: return
  subscribers[topic] = subscribers[topic].filter((l) => l != listener)
  if subscribers[topic].len == 0: subscribers.del topic
  log fmt"{listener} unsubscribed from {topic}"

proc unsubscribe*(redis: RedisNode, listener: Node): void {.nexport.} =
  var topics: seq[string]
  for topic in subscribers.keys: topics.add topic
  for topic in topics: unsubscribe(redis, listener, topic)
  log fmt"{listener} unsubscribed from all topics"

proc publish*(redis: RedisNode, topic: string, message: string): void {.nexport.} =
  last_messages[topic] = message
  if topic notin subscribers: return
  log fmt"publishing new message in {topic} to {subscribers[topic].len} listeners"
  for listener in subscribers[topic]:
    if listener notin notify_queue: notify_queue[listener] = @[]
    if topic notin notify_queue[listener]: notify_queue[listener].add topic
    let l = listener
    if listener notin running_notifiers: spawn_async () => run_notifier(redis, l)

# Calling `notify` on the listener node.
proc notify(listener: Node, topic: string, message: string): Future[void] {.async, nimport.} = discard

proc run_notifier(redis: RedisNode, listener: Node): Future[void] {.async.} =
  # Each subscriber has its own async notifier to handle different
  # network speed and timeouts
  while true:
    if listener notin notify_queue or notify_queue[listener].len == 0:
      break
    let topic = notify_queue[listener].pop
    try:
      await listener.notify(topic, last_messages[topic])
    except:
      log fmt"can't deliver message to {listener}"
      # Cleaning the queue but don't removing listener, as it can go online later
      break
  notify_queue.del listener
  running_notifiers = running_notifiers.filter((l) => l != listener)

proc add_unique[T](list: var seq[T], v: T): void =
  if v notin list: list.add v

proc log(msg: string): void = echo "  " & msg

if is_main_module:
  let redis = redis_node"redis"
  # redis.define  "tcp://localhost:4000" # Optional, will be auto-set

  generate_nimports "./nodem/examples/redis/redisi.nim"

  # catch_node_errors = false
  spawn_async redis.run
  spawn_async redis.run_http("http://localhost:8000", @["get", "get_counter"]) # Optional, for HTTP
  echo "redis started"
  run_forever()