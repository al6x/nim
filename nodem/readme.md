Simple RPC, call remote Nim functions as if its local

[Video Demo, 10min](https://youtu.be/KUb15vva0vw)

Made by [al6x](http://al6x.com)

# Example

Exporting `pi` and `multiply` functions as remote functions:

```Nim
import nodem

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b

Address("math").run true
```

Calling remote functions in another Nim process:

```Nim
import ./mathi

echo multiply(pi(), 2)
# => 6.28
```

See `math_example` and `greeting_example`, remote functions also available via REST JSON API,
see `nodem/httpm.nim`.

# Features

- RPC between Nim Processes, with multi dispatch
- REST API for React.JS / Karax, no need to define REST API and routes explicitly.
- Sync Client and Server Functions via functions declaration file.
- Generate Nim Client from Nim Server.
- Generate Nim Client Function for Java/Node/Elixir REST API with `nimport`.
- [todo] Generate TypeScript/Java/Node/Elixir Client functions from Nim Server.
- There's no server or client, every node is both server and client. No RPC, just nexport/nimport
- No urls, use node names, like `red_node` or `math_service`.
- Efficient networking with `asyncdispatch` and `TCP`.
- REST API and Browser support, function could be called via REST API

# Notes

- Serialization https://github.com/treeform/jsony https://github.com/disruptek/frosty
  https://github.com/treeform/flatty

# License

MIT

Please keep "Initial version made by http://al6x.com" line in readme if you fork it.