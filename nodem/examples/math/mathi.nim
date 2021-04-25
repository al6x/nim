# Auto-generated code, do not edit
import nodem
export nodem

let math* = Node("math")

proc pi*(): float {.nimport_from: math.} = discard

proc multiply*(a: float, b: float): float {.nimport_from: math.} = discard

proc multiply*(a: string, b: string): string {.nimport_from: math.} = discard

proc plus*(x: float, y: float): Future[float] {.nimport_from: math.} = discard