import nodem, asyncdispatch

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b

proc plus(a, b: float): Future[float] {.async, nexport.} = return a + b

let address = Address("math") # address is just `distinct string`
address.generate_nimport
address.run