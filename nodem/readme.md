Simple RPC, call remote Nim functions as if its local

[Video Demo, 10min, a bit outdated, for previous version](https://youtu.be/KUb15vva0vw)

Made by [al6x](http://al6x.com), I do Statstics, Visualization, Finance

# RPC in 10 lines of Nim

Exporting some functions as available over network:

```Nim
import nodem

proc plus(_: Node, a, b: float): float {.nexport.} = a + b

node"server".run_forever
```

And calling it from another process:

```Nim
import nodem

proc plus*(node: Node, a: float, b: float): float {.nimport.} = discard

echo node"server".plus(3, 2)
# => 5
```

Connect/disconnect/reconnect handled automatically. Also, the client functions could be auto-generated,
making the client code even shorter. See `examples/rpc_in_10_lines`.

# Web Server in 5 lines of Nim

```Nim
import nodem, nodem/httpm

proc plus(_: Node, a, b: float): float {.nexport.} = a + b

node"server".run_http_forever("http://localhost:8000", true)

# curl http://localhost:8000/plus/1?b=2
#
# => {"is_error":false,"result":3.0}
#
# - Arguments auto casted to correct types.
# - Both positional and named arguments supported.
```

See `examples/web_server_in_5_lines`. Note, [todo] the HTTP Client API could be auto-generated in TypeScript.

# Math example

Exporting some functions as available over network:

```Nim
import nodem, nodem/httpm

proc pi(_: Node): float {.nexport.} = 3.14

proc multiply(_: Node, a, b: float): float {.nexport.} = a * b
proc multiply(_: Node, a, b: string): string {.nexport.} = a & b # Multi dispatch supported

proc plus(_: Node, x, y: float): Future[float] {.async, nexport.} = return x + y # Async supported

if is_main_module:
  let math = node"math"
  # math.define "tcp://localhost:4000" # Optional, will be auto-set

  generate_nimports "./nodem/examples/math/mathi.nim" # Optional

  spawn_async math.run
  spawn_async math.run_http("http://localhost:8000", true) # Optional, for HTTP

  echo "math node started"
  run_forever()
```

And calling it from another process:

```Nim
include ./mathi

let math = node"math"

echo math.multiply(math.pi(), 2)
# => 6.28

echo math.multiply("A", "x")
# => Ax

echo wait_for math.plus(1, 2)
# => 3

# math.define "tcp://localhost:4000" # optional, will be auto-set
```

Or calling via HTTP, [todo] with auto-generated TypeScript/LangXXX client functions

```Bash
curl http://localhost:8000/plus/1?y=2
echo

# => {"is_error":false,"result":3.14}
#
# - Arguments were auto casted to correct types.
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
```

see `examples/math`.

# Redis in 100 lines

See `examples/redis`

# Async example

[TODO] outdated, needs to be updated.

For nodes working as both client and server simultaneously with nested, circular calls check `examples/greeting`.

While async is faster, and in some cases very much faster, in many cases it's not give much speed improvements
and only adds more complexity. If in doubt, it's better to avoid it, and use it only for special cases,
when you know that it's really needed.

# Messaging example

The underlying network transport provided by `nodem/netm`, tiny Erlang-like networking messaging. It could be
useful when RPC is not needed and sending just messages is enough, there's example at the end of the file.

# Features

- **Call remote function as local**, with multi-dispatch, exceptions, async support.
- There's **no server or client**, every node is both server and client. No RPC, just nexport/nimport.
- **Use names** like `red_node` or `math`, avoid explicit URLs `tcp://localhost:6000`, like IoC.
- **No connections**, managed automatically, connect, re-connect, disconnected if not used.
- Is **fast** as async-IO used.
- Is **fast for sync functions too**, as they also use async-IO underneath, see note below.
- **Clean error messages**, without messy async stack traces.
- REST API and Browser support, function could be called via REST API, [todo] with auto-generated TypeScript API.
- With async calls possible **simultaneous, nested, circular calls** like `a -> b -> a`.
- REST API for React.JS / Karax, no need to define REST API and routes explicitly.

Nexported functions both sync and async always use async-IO and never block the network. This makes it
possible to build fast in-memory servers like Redis, having both simple sync functions with clean error
messages and fast IO.

Nimported functions use async IO only if they are async.

Design inspired by **Erlang Actors**.

**HTTP Features:**

- **Auto-routing** `/fn/a/b` -> `fn(a, b)`, no need for router.
- Both **positional and named arguments** supported `/fn/a/b`, or `/fn?a=a&b=b` or `/fn/a?b=b`.
- **Auto-parsing** from `querystring` stirng into correct argument types.
- By default only POST allowed, GET needs to be explicitly enabled, for security reasons.
- Is **fast**, as async HTTP server is used.

**Other features:**

- Match Client and Server Functions via functions declaration file.
- Generate Nim Client from Nim Server.
- Generate Nim Client Function for Java/Node/Elixir REST API with `nimport`.
- [todo] Generate TypeScript/Java/Node/Elixir Client functions from Nim Server.
- Auto-versioning, signature of remote functions validated to match the local function, via `full_name`.
- Idempotent timeouts, waiting for node to get running.

# If used with Elixir-bridge

The **main use case is to communicate between Nim processes**. It's also possible to communicte with other
languages. One special case is Elixir-birdge, giving Nim access to excellent Elixir IO runtime and capabilities.

*Elixir-bridge is worik in progress, once it's done, these features will be available*.

CPU-fast Nim with IO-fast Elixir working as Team. Write 97% of code in Nim and get capabilities and IO speed of
Elixir at the cost of writing only 3% of code in Elixir. Mostly the standard code that could be searched and
copy-pasted.

Using Elixir-bridge is like using PostgreSQL or MongoDB, but for IO.

- Advanced IO without effort with Elixir. Realtime streaming, auth, rate-limits, binary storage, Browser-IO integrations, robust networking, DB-access, scaling, MQ, caching, and so on and on.
- Fast binary IO, as the binary data handled by Elixir, only ref managed by Nim.
- Access to tons of excellent, fast, fully async drivers, via Elixir.
- Use simple single-threaded development model. As CPU-bound parallelism is solved well by single-threaded
  multiple Nim nodes, processes. And most IO-bound parallelism would be handled by Elixir.
- Fast compile time for Nim, as you don't have dependencies like MongoDB or PostgreSQL drivers etc.

# Performance

The main use case is hundreds of nodes in local network exchanging lots of small messages.

Current limitations and possible areas for improvements:

- Messages passed by copying, could be improved with move semantics.
- std/json used for serialisation, faster serialization could be used.
- Two TCP sockets used for communication, it's possible to use only one, but it would complicate the
  implementation, and it shouldn't matter, as there are only couple of hundreds of nodes not thousands.

# TODO

- RPC in 10 and Web Server in 5 lines of Nim
- TypeScript and Elixir integration.
- [low] Add support for defaults.
- [low] Manager to start/restart

# Notes

- Serialization https://github.com/treeform/jsony https://github.com/disruptek/frosty
  https://github.com/treeform/flatty

# License

MIT

Please keep "Initial version made by http://al6x.com" line in readme if you fork it.