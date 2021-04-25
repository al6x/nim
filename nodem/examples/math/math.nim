import nodem, nodem/httpm

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b
proc multiply(a, b: string): string {.nexport.} = a & b # Multi dispatch supported

proc plus(x, y: float): Future[float] {.async, nexport.} = return x + y # Async supported

if is_main_module:
  let math = Node("math")
  # math.define  "tcp://localhost:4000" # Optional, will be auto-set

  math.generate_nimport

  spawn_async math.run_http("http://localhost:8000", @["plus"]) # Optional, for HTTP
  math.run