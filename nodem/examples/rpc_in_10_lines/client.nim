import nodem

proc plus*(node: Node, a: float, b: float): float {.nimport.} = discard

echo node"server".plus(3, 2)
# => 5