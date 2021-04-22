UPDATE: Checkout [nodes](./nodes) it has the new implementation.

---

Simple RPC, call remote Nim functions as if its local

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

# TODO

- [todo] Implement more efficient networking with `asyncdispatch`, `TCP` and Nim native serialisation.

# Example

Nim Server, exposing `pi` and `multiply` functions.

```Nim
import rpc/rpcm

proc pi: float {.sfun.} = 3.14

proc multiply(a, b: float): float {.sfun.} = a * b

rserver.run
```

Nim Client, multiplying `pi` by `2`.

```Nim
import rpc/rpcm

proc pi: float = cfun pi

proc multiply(a, b: float): float = cfun multiply

echo multiply(pi(), 2)
# => 6.28
```

Also available as REST JSON API

```
curl --request POST --data '{"a":4,"b":2}' http://localhost:5000/rpc/multiply?format=json
```

# Current status

It's already working (there's a bug in `cfun` macro it incorrectly getting function argument and return types...), but needs some refactoring and implementing the network transport in a more
efficient way with TCP and asyncdispatch, and, I haven't published it to Nimble yet.

# Notes

- Networking https://nim-lang.org/docs/asyncnet.html
- Serialization https://github.com/treeform/jsony https://github.com/disruptek/frosty
  https://github.com/treeform/flatty

# License

MIT

Please keep "Initial version made by http://al6x.com" line in readme if you fork it.