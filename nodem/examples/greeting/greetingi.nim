# Auto-generated code, do not edit
import nodem
export nodem

let greeting* = Node("greeting")

proc say_hi*(prefix: string): Future[string] {.nimport_from: greeting.} = discard