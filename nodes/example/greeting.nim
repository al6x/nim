import nodes/rpcm

proc hi(name: string): string {.nexport.} = "Hi " & name

if is_main_module:
  let math = Node("greeting")
  generate_nimport(math, "./nodes/example")
  math.run