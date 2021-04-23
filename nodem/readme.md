Simple RPC, call remote Nim functions as if its local

[Video Demo, 10min](https://youtu.be/KUb15vva0vw)

Made by [al6x](http://al6x.com)

# Example

Exporting some functions as available over network:

```Nim
import nodem, asyncdispatch

proc pi: float {.nexport.} = 3.14

proc multiply(a, b: float): float {.nexport.} = a * b

proc plus(a, b: float): Future[float] {.async, nexport.} = return a + b

let address = Address("math") # address is just `distinct string`
address.generate_nimport
address.run
```

And calling it from another process:

```Nim
import ./mathi

echo multiply(pi(), 2)
# => 6.28

echo wait_for plus(1, 2)
# => 3
```

See `math_example`, remote functions also available via REST JSON API, see `nodem/httpm.nim`.

# Async example

For nodes working as both client and server simultaneously with nested, circular calls check `greeting_example`.

# Messaging example

The underlying network transport provided by `nodem/anetm`, tiny Erlang-like networking messaging. It could be
useful when RPC is not needed and sending just messages is enough, there's example at the end of the file.

# Features

- **Call remote function as local**, with multi dispatch.
- REST API for React.JS / Karax, no need to define REST API and routes explicitly.
- Match Client and Server Functions via functions declaration file.
- Generate Nim Client from Nim Server.
- Generate Nim Client Function for Java/Node/Elixir REST API with `nimport`.
- [todo] Generate TypeScript/Java/Node/Elixir Client functions from Nim Server.
- There's **no server or client**, every node is both server and client. No RPC, just nexport/nimport.
- **Use node names** like `red_node` or `math`, avoid explicit URLs `tcp://localhost:6000`.
- **No connection**, connection will be crated automatically on demand, and re-connect if needed.
- Plain, simple code, even though internally async networking is used. Optionally, you can use async.
- REST API and Browser support, function could be called via REST API.
- With async calls possible **simultaneous, nested, circular calls** like `a -> b -> a`.
- Should be **really fast** if used with async functions.

# TODO

- TypeScript and Elixir integration.

# Notes

- Serialization https://github.com/treeform/jsony https://github.com/disruptek/frosty
  https://github.com/treeform/flatty

# License

MIT

Please keep "Initial version made by http://al6x.com" line in readme if you fork it.