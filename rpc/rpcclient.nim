import ./rpcm

proc pi: float = cfun pi

proc multiply(a, b: float): float = cfun multiply

echo multiply(pi(), 2)
