import nodem, options

type RedisNode* = ref object of Node
proc redis_node*(id: string): RedisNode = RedisNode(id: id)

# Counters ------------------------------------------------
proc inc_counter*(_: RedisNode, counter: string): void {.nimport.} = discard
proc get_counter*(_: RedisNode, counter: string): int {.nimport.} = discard
proc del_counter*(_: RedisNode, counter: string): void {.nimport.} = discard

# K/V store -----------------------------------------------
proc get*(_: RedisNode, k: string): Option[string] {.nimport.} = discard
proc set*(_: RedisNode, k: string, v: string): void {.nimport.} = discard

# Pub/Sub -------------------------------------------------
proc subscribe*(_: RedisNode, listener: Node, topic: string): void {.nimport.} = discard
proc unsubscribe*(_: RedisNode, listener: Node, topic: string): void {.nimport.} = discard
proc unsubscribe*(_: RedisNode, listener: Node): void {.nimport.} = discard
proc publish*(_: RedisNode, topic: string, message: string): void {.nimport.} = discard