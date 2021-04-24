import asyncdispatch, nodem, nodem/httpm

proc pi(): float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b

if is_main_module:
  async_check receive_http("http://localhost:8000", nexport_handler_async, allow_get = @["pi"]) # for HTTP

  let math = Address("math") # address is just `distinct string`
  math.run # for TCP

# curl \
# --request POST \
# --data '{"fn":"multiply(a: float, b: float): float","args":[3.14,2.0]}' \
# http://localhost:8000

# => {"is_error":false,"result":6.28}

# Also available with shorter name

# curl http://localhost:8000/pi

# => {"is_error":false,"result":3.14}

