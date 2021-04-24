import asyncdispatch, nodem, nodem/httpm

async_check receive_http("http://localhost:8000", nexport_handler_async) # for HTTP
include ./math

# curl \
# --request POST \
# --data '{"fn":"multiply(a: float, b: float): float","args":[3.14,2.0]}' \
# http://localhost:8000

# => {"is_error":false,"result":6.28}

