import nodem

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b

if is_main_module:
  let math = Address("math")
  generate_nimport(math, "./nodes/math_example")
  math.run