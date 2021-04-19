import ./rpcm, web/serverm

proc pi: float {.sfun.} = 3.14

proc multiply(a, b: float): float {.sfun.} = a * b

rserver.run


