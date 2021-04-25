import nodem

proc multiply(a, b: float): float {.nexport.} = a * b

if is_main_module:
  let server = Node("server")
  server.generate_nimport
  server.run