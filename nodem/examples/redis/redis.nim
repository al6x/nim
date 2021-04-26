import nodem, options, sugar, sequtils, sets


# Client API ----------------------------------------------
# proc inc_counter*(counter: string): void
# proc get_counter*(counter: string): int
# proc del_counter*(counter: string): void

# proc get_cache*(k: string): Option[string]
# proc set_cache*(k: string, v: string): void

# proc subscribe*(node: Node, topic: string): void
# proc unsubscribe*(node: Node, topic: string): void
# proc publish*(topic: string, message: string): void

proc notify(node: Node, message: string): Future[void]

# Counters ------------------------------------------------
var counters: CountTable[string]
proc inc_counter*(counter: string): void {.nexport.} =
  counters.inc counter

proc get_counter*(counter: string): int {.nexport.} =
  counters[counter]

proc del_counter*(counter: string): void {.nexport.} =
  counters.del counter


# Cache ---------------------------------------------------
var cache: Table[string, string]
proc get_cache*(k: string): Option[string] {.nexport.} =
  if k in cache: cache[k].some else: string.none

proc set_cache*(k: string, v: string): void {.nexport.} =
  cache[k] = v


# Pub/Sub -------------------------------------------------
var last_messages: Table[string, string]        # topic -> message
var subscribers:   Table[string, seq[Node]]     # topic -> subscribers
var notify_queue:  Table[Node, HashSet[string]] # subscriber -> updated topics
var running_notifiers: HashSet[Node]

proc subscribe*(node: Node, topic: string): void {.nexport.} =
  var listeners = subscribers.get_or_default(topic, @[])
  if node notin listeners: listeners.add node

proc unsubscribe*(node: Node, topic: string): void {.nexport.} =
  if topic notin subscribers: return
  let listeners = subscribers[topic].filter((n) => n != node)
  if listeners.len > 0: subscribers[topic] = listeners
  else:                 subscribers.del topic

proc unsubscribe*(node: Node): void {.nexport.} =
  for topic, nodes in subscribers:
    subscribers[topic] = nodes.filter((n) => n != node)

# Calling `notify` on the listener node.
proc notify(node: Node, message: string): Future[void] {.nimport.} = discard

proc get_any[T](hset: HashSet[T]): T =
  for v in hset: return v
  raise new_exception(Exception, "set is empty")

proc run_notifier(node: Node): Future[void] {.async.} =
  # Each subscriber has its own async notifier to handle different
  # network speed and timeouts
  while true:
    var updated_topics = notify_queue[node]
    if updated_topics.len == 0:
      notify_queue.del node
      break
    try:
      let topic = updated_topics.get_any
      await node.notify last_messages[topic]
      updated_topics.excl topic
    except:
      running_notifiers.excl node
      node.unsubscribe
      break
  running_notifiers.excl node

proc publish*(topic: string, message: string): void {.nexport.} =
  last_messages[topic] = message
  for node in subscribers[topic]:
    if node notin notify_queue: notify_queue[node] = init_hash_set[string]()
    notify_queue[node].incl topic
    if node notin running_notifiers: spawn_async () => node.run_notifier()


# Run -----------------------------------------------------
if is_main_module:
  let redis = Node("redis")
  redis.generate_nimport
  redis.run