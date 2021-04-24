import asyncdispatch, nodem, nodem/httpm

proc multiply(a, b: float): float {.nexport.} = a * b

if is_main_module:
  let math = Address("math") # address is just `distinct string`

  async_check receive_http("http://localhost:8000", nexport_handler_async) # for HTTP
  math.run # for TCP

# curl \
# --request POST \
# --data '{"fn":"multiply(a: float, b: float): float","args":[3.14,2.0]}' \
# http://localhost:8000

# => {"is_error":false,"result":6.28}