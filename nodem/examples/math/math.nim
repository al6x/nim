import asyncdispatch, nodem, nodem/httpm

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b
proc multiply(a, b: string): string {.nexport.} = a & b # Multi dispatch supported

proc plus(x, y: float): Future[float] {.async, nexport.} = return x + y # Async supported

if is_main_module:
  let math = Address("math") # Address is just `distinct string`
  # math.define "tcp://localhost:4000" # Optional, will be auto-set

  async_check receive_http("http://localhost:8000", allow_get = @["plus"]) # Optional, for HTTP

  math.generate_nimport
  math.run # for TCP