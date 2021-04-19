import rpc/rpcm

proc pi: float {.sfun.} = 3.14

proc multiply(a, b: float): float {.sfun.} = a * b

generate_cfuns("./rpc/example/rapi_generated.nim")
rserver.run