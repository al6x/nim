import ./rpcm

proc pi: float
proc multiply(a, b: int): int

proc pi: float = cfun pi
proc multiply(a, b: int): int = cfun multiply

echo pi()
echo multiply(4, 2)