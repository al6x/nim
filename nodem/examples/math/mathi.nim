import nodem

type MathNode* = ref object of Node
proc math_node(id: string): MathNode = MathNode(id: id)

proc pi(_: MathNode): float {.nexport.} = 3.14

proc multiply(_: MathNode, a, b: float): float {.nexport.} = a * b
proc multiply(_: MathNode, a, b: string): string {.nexport.} = a & b # Multi dispatch supported

proc plus(_: MathNode, x, y: float): Future[float] {.async, nexport.} = return x + y # Async supported