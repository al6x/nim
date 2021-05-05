import nodem, nodem/httpm

proc plus(_: Node, a, b: float): float {.nexport.} = a + b

run_rest_forever("http://localhost:8000", true)

# curl http://localhost:8000/plus/1?b=2
#
# => {"is_error":false,"result":3.0}
#
# - Arguments auto casted to correct types.
# - Both positional and named arguments supported.