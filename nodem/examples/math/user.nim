include ./mathi

let math = math_node"math"

echo math.multiply(math.pi(), 2)
# => 6.28

echo math.multiply("A", "x")
# => Ax

echo wait_for math.plus(1, 2)
# => 3

# math.define "tcp://localhost:4000" # optional, will be auto-set