import nodem, nodem/httpm

proc pi(_: Node): float {.nexport.} = 3.14

proc multiply(_: Node, a, b: float): float {.nexport.} = a * b
proc multiply(_: Node, a, b: string): string {.nexport.} = a & b # Multi dispatch supported

proc plus(_: Node, x, y: float): Future[float] {.async, nexport.} = return x + y # Async supported

if is_main_module:
  let math = node"math"
  # math.define "tcp://localhost:4000" # Optional, will be auto-set

  generate_nimports "./nodem/examples/math/mathi.nim" # Optional

  spawn_async math.run
  spawn_async math.run_http("http://localhost:8000", true) # Optional, for HTTP

  echo "math node started"
  run_forever()