import nodem

proc plus(_: Node, a, b: float): float {.nexport.} = a + b

node"server".run_forever