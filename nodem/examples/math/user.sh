curl http://localhost:8000/plus/1/2
echo

# => {"is_error":false,"result":3.14}
# Note that arguments were auto casted to correct types

curl http://localhost:8000/plus/1/a
echo

# = {"is_error":true,"message":"invalid float: a"}

# Also available as POST with JSON

curl \
--request POST \
--data '{"fn":"multiply(a: float, b: float): float","args":[3.14,2.0]}' \
http://localhost:8000
echo

# # => {"is_error":false,"result":6.28}