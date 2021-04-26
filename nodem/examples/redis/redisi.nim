# Auto-generated code, do not edit
import nodem
export nodem

let redis* = Node("redis")

proc inc_counter*(counter: string): void {.nimport_from: redis.} = discard

proc get_counter*(counter: string): int {.nimport_from: redis.} = discard

proc del_counter*(counter: string): void {.nimport_from: redis.} = discard

proc get_cache*(k: string): Option[string] {.nimport_from: redis.} = discard

proc set_cache*(k: string, v: string): void {.nimport_from: redis.} = discard

proc subscribe*(topic: string, self: Node): void {.nimport_from: redis.} = discard

proc unsubscribe*(topic: string, self: Node): void {.nimport_from: redis.} = discard

proc publish*(topic: string, price: float): void {.nimport_from: redis.} = discard