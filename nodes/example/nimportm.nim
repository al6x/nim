import nodes/rpcm

export rpcm

let math* = NodeName("math")

proc multiply*(a: float, b: float): float = nimport(math, multiply)

proc pi*(): float = nimport(math, pi)