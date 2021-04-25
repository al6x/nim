# Auto-generated code, do not edit
import nodem
export nodem

let server* = Node("server")

proc multiply*(a: float, b: float): float {.nimport_from: server.} = discard