# Auto-generated code, do not edit
import nodem, asyncdispatch
export nodem, asyncdispatch

let math* = Address("math")

proc plus*(x: float, y: float): Future[float] {.async.} =
  return await nimport_async(math, plus)

proc multiply*(a: float, b: float): float =
  nimport(math, multiply)

proc multiply*(a: string, b: string): string =
  nimport(math, multiply)

proc pi*(): float =
  nimport(math, pi)