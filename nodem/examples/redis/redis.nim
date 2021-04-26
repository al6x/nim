import nodem, nodem/httpm, options, sugar, sequtils, sets


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
var last_messages: Table[string, string]        # topic -> message
var subscribers:   Table[string, HashSet[Node]]     # topic -> subscribers
var notify_queue:  Table[Node, HashSet[string]] # subscriber -> updated topics
var running_notifiers: HashSet[Node]

proc subscribe(listener: Node, topic: string): void =
  if topic notin subscribers: subscribers[topic] = init_hash_set[Node]()
  if listener notin subscribers[topic]: subscribers[topic].incl listener

proc subscribe*(_: RedisNode, listener: Node, topic: string): void {.nexport.} =
  subscribe(listener, topic)

proc unsubscribe(listener: Node, topic: string): void {.nexport.} =
  if topic notin subscribers: return
  var list = subscribers[topic]
  list.excl listener
  if list.len == 0: subscribers.del topic

proc unsubscribe*(_: RedisNode, listener: Node, topic: string): void {.nexport.} =
  unsubscribe(listener, topic)

proc unsubscribe(listener: Node): void =
  for topic, _ in subscribers: unsubscribe(listener, topic)
proc unsubscribe*(_: RedisNode, listener: Node): void {.nexport.} =
  listener.unsubscribe

# Calling `notify` on the listener node.
proc notify(listener: Node, topic: string, message: string): Future[void] {.async, nimport.} = discard

proc run_notifier(listener: Node): Future[void] {.async.} =
  # Each subscriber has its own async notifier to handle different
  # network speed and timeouts
  while true:
    if notify_queue[listener].len == 0:
      notify_queue.del listener
      break
    let topic = notify_queue[listener].pop
    try:
      await listener.notify(topic, last_messages[topic])
    except:
      running_notifiers.excl listener
      unsubscribe(listener)
      break
  running_notifiers.excl listener

proc publish_impl(topic: string, message: string): void =
  last_messages[topic] = message
  if topic notin subscribers: return
  for listener in subscribers[topic]:
    if listener notin notify_queue: notify_queue[listener] = init_hash_set[string]()
    notify_queue[listener].incl topic
    let l = listener
    if listener notin running_notifiers: spawn_async () => l.run_notifier()

proc publish*(node: RedisNode, topic: string, message: string): void {.nexport.} =
  publish_impl(topic, message)


# Running Math node ---------------------------------------
let redis = redis_node"redis"
# redis.define  "tcp://localhost:4000" # Optional, will be auto-set

catch_node_errors = false
spawn_async redis.run
spawn_async run_node_http_adapter("http://localhost:8000", @["get"]) # Optional, for HTTP
echo "redis started"
run_forever()