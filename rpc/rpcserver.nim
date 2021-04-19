import ./rpcm, web/serverm

proc pi: float = 3.14
sfun pi

proc multiply(a, b: int): int = a * b
sfun multiply

rserver.run