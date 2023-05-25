# Auto-generated code, do not edit
import nodem, options, tables

type RedisNode* = ref object of Node
proc redis_node*(id: string): RedisNode = RedisNode(id: id)

proc inc_counter*(node: RedisNode, counter: string): void {.nimport.} = discard

proc get_counter*(node: RedisNode, counter: string): int {.nimport.} = discard

proc del_counter*(node: RedisNode, counter: string): void {.nimport.} = discard

proc get*(node: RedisNode, k: string): Option[string] {.nimport.} = discard

proc set*(node: RedisNode, k: string, v: string): void {.nimport.} = discard

proc subscribe*(node: RedisNode, listener: Node, topic: string): void {.nimport.} = discard

proc unsubscribe*(node: RedisNode, listener: Node, topic: string): void {.nimport.} = discard

proc unsubscribe*(node: RedisNode, listener: Node): void {.nimport.} = discard

proc publish*(node: RedisNode, topic: string, message: string): void {.nimport.} = discard