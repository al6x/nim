import nodes/rpcm, nodes/messages_asyncm

let math = NodeName("math")

proc pi: float {.nexport: math.} = 3.14

proc multiply(a, b: float): float {.nexport: math.} = a * b

# Same functions could be used on server, or remotely, same way
echo multiply(pi(), 2)

# Generating nimport
generate_nimport "./nodes/example/nimportm.nim"

# Handling remote calls
nodes_names[math] = "tcp://localhost:4000"
math.on_receive nexport_handler