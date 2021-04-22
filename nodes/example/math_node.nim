import nodes/rpcm

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b

if is_main_module:
  let math = Node("math")
  generate_nimport(math, "./nodes/example/nimportm")
  math.run