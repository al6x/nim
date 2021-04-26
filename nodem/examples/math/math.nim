import nodem, nodem/httpm

type MathNode* = ref object of Node
proc math_node(id: string): MathNode = MathNode(id: id)

# Math node impl ------------------------------------------
proc pi(_: MathNode): float {.nexport.} = 3.14

proc multiply(_: MathNode, a, b: float): float {.nexport.} = a * b
proc multiply(_: MathNode, a, b: string): string {.nexport.} = a & b # Multi dispatch supported

proc plus(_: MathNode, x, y: float): Future[float] {.async, nexport.} = return x + y # Async supported

# Running Math node ---------------------------------------
let math = math_node"math"
# math.define  "tcp://localhost:4000" # Optional, will be auto-set

spawn_async math.run
spawn_async run_node_http_adapter("http://localhost:8000", @["plus"]) # Optional, for HTTP
echo "math node started"
run_forever()