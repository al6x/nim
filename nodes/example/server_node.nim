import nodes/rpcm

let math = NodeName("math")

proc pi: float {.nexport: math.} = 3.14

proc multiply(a, b: float): float {.nexport: math.} = a * b

if is_main_module:
  generate_nimport "./nodes/example/nimportm.nim"
  math.run