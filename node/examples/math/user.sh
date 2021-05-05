curl http://localhost:8000/math/plus/1?y=2
echo

# => {"is_error":false,"result":3}
#
# - Arguments auto casted to correct types.
# - Both positional and named arguments supported.

curl http://localhost:8000/math/plus/1/a
echo

# = {"is_error":true,"message":"invalid float: a"}

# Also available as POST with JSON

curl \
--request POST \
--data '{"x": 1, "y": 2}' \
http://localhost:8000/math/plus
echo

# => {"is_error":false,"result":3.0}