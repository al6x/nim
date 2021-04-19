import ./rpcm, web/serverm

proc pi: float
proc multiply(a, b: int): int

proc pi: float = 3.14
sfun pi

proc multiply(a, b: int): int = a * b
sfun multiply

rserver.run