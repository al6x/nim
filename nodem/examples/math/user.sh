curl http://localhost:8000/plus/1?y=2
echo

# => {"is_error":false,"result":3}
#
# - Arguments auto casted to correct types.
# - Both positional and named arguments supported.

curl http://localhost:8000/plus/1/a
echo

# = {"is_error":true,"message":"invalid float: a"}

# Also available as POST with JSON

curl \
--request POST \
--data '{"fn":"multiply(node: Node, a: float, b: float): float","args":["math",3.14,2.0]}' \
http://localhost:8000
echo

# => {"is_error":false,"result":6.28}