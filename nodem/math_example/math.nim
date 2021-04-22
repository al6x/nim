import nodem, asyncdispatch

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b

proc plus(a, b: float): Future[float] {.async, nexport.} = return a + b

Address("math").run(generate = true)