import ./rpcm, web/serverm

proc pi: float {.sfun.} = 3.14

proc multiply(a, b: float): float {.sfun.} = a * b

generate_cfuns("./rpc/rapi_generated.nim")
rserver.run