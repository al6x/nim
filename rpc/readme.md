Simple RPC, call remote Nim functions as if it's usual function

[Video Demo, 10min](https://youtu.be/KUb15vva0vw)

Made by [al6x](http://al6x.com)

# Features

- RPC between Nim Processes.
- REST API for React.JS / Karax, no need to define REST API and routes explicitly.
- Sync Client and Server Functions via functions declaration file.
- [todo] Auto generate Nim Client from Nim Server.
- Format negotiation, for Nim Clients Server respond with TCP and Nim fast serialization format, for
  REST API with JSON over HTTP, MessagePack also could be supported.
- Generate Nim Client Function for Java/Node/Elixir REST API with `cfun`.
- [todo] Generate TypeScript/Java/Node/Elixir Client from Nim Server.

# Example

Nim Server, exposing `pi` and `multiply` functions.

```Nim
import ./rpcm, web/serverm

proc pi: float = 3.14
sfun pi

proc multiply(a, b: float): float = a * b
sfun multiply

rserver.run
```

Nim Client, multiplying `pi` by `2`.

```Nim
import ./rpcm

proc pi: float = cfun pi

proc multiply(a, b: float): float = cfun multiply

echo multiply(pi(), 2)
# => 6.28
```

Also available as REST JSON API

```
curl --request POST --data '{"a":4,"b":2}' http://localhost:5000/rpc/multiply?format=json
```

# Notes

- Networking https://nim-lang.org/docs/asyncnet.html
- Serialization https://github.com/treeform/jsony https://github.com/treeform/flatty
