import nodem

type MathNode* = ref object of Node
proc math_node(id: string): MathNode = MathNode(id: id)

proc pi(node: MathNode): float {.nimport.} = discard

proc multiply(node: MathNode, a, b: float): float {.nimport.} = discard
proc multiply(node: MathNode, a, b: string): string {.nimport.} = discard

proc plus(node: MathNode, x, y: float): Future[float] {.async, nimport.} = discard