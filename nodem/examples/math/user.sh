curl \
--request POST \
--data '{"fn":"multiply(a: float, b: float): float","args":[3.14,2.0]}' \
http://localhost:8000
echo

# => {"is_error":false,"result":6.28}

# Also available with shorter name

curl http://localhost:8000/plus/1/2
echo

# => {"is_error":false,"result":3.14}

curl http://localhost:8000/plus/1/a
echo

# = {"is_error":true,"message":"invalid float: a"}