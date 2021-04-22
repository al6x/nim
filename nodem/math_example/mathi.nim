# Auto-generated code, do not edit
import nodem, asyncdispatch
export nodem, asyncdispatch

proc multiply*(a: float, b: float): float =
  nimport("math", multiply)

proc pi*(): float =
  nimport("math", pi)

proc plus*(a: float, b: float): Future[float] {.async.} =
  return await nimport_async("math", plus)