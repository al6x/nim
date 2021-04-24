# Auto-generated code, do not edit
import nodem, asyncdispatch
export nodem, asyncdispatch

let server* = Address("server")

proc multiply*(a: float, b: float): float {.nimport_from: server.} = discard