import nodem, asyncdispatch

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b
proc multiply(a, b: string): string {.nexport.} = a & b  # Multi dispatch supported

proc plus(x, y: float): Future[float] {.async, nexport.} = return x + y

let math = Address("math") # address is just `distinct string`
# math.define "tcp://localhost:4000" # optional, will be auto-set
math.generate_nimport
math.run