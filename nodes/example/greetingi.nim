import nodes/rpcm

export rpcm

proc hi*(name: string): string = nimport("greeting", hi)