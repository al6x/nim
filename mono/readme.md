Nim UI/Web/Desktop/Mobile Framework

High productivity, simple, short and clean code.

Checkout [Video Demo](https://www.youtube.com/watch?v=vjj0mZOh5h4) or [Todo Example](mono/examples/todo.nim)

```
nimble install https://github.com/al6x/nim?subdir=mono
nim r --experimental:overloadable_enums --threads:off todo.nim
```

![](readme/todo.png)

# Features

- Reactive, like Svelte or React.
- Stateful Components and bidirectional data binding.
- Fast initial page load and SEO friendly.
- Works on Nim Server, or Compile to JS in Browser.
- Support for Browser Title, Location, Favicon, Back/Forward Buttons.

# Component Templates

- Clean UI with Components similar to Svelte or JSX.
- Components are interactive atomic blocks.
- Stateless Functional and Stateful Object Components.
- Template is plain Nim code.
- Slots, block passed as additional `content: seq[El]` argument.
- Also, custom slots could be used in block scope, like `layout.left/right`.
- Tag shortcut helps keep code small.
- No wait for Nim compilation, plays well with Tailwind, autocomplete etc.
- Context with `threadvar`.

# Install

`nimble install https://github.com/al6x/nim?subdir=mono`

Then run [Todo Example](mono/examples/todo.nim) and start experimenting.

Use `import base/log; log_emitters.len = 0` to silence the default console logger.

# Limitations

I'm using this for a private app, and going to fix bugs as I encounter them.

Some edge cases might not be tested, some HTML inputs haven't been tested.

Currently `-mm:orc` doesn't work, will work with the next Nim release.

# Development and contributing

Checkout the repo, then run

- `nim r --experimental:overloadable_enums --threads:off mono/test.nim test` for tests.
- `nim r --experimental:overloadable_enums --threads:off mono/examples/todo.nim` for example.

The whole library is just one function

```Nim
let out: seq[OutEvent] = component.process(events: seq[InEvent])
```

Checkout [core](mono/core) and tests to see how it works.

Other packages are adapters to connect that function to different environments like Browser or Server.
And provide transport for messages, like HTTP. You could replace it with your own adapter and transport,
like WebSocket.

I use a simple HTTP server and not WebSocket, because I want to avoid dependencies and
keep the code size small, to have fast Nim compilation. You can change that and rewrite server to use WebSocket.

# Todo

- Move current_tree from component to session. And replace get_initial_el with session.current_tree.get
- Twitter Example
- Browser Adapter with multiple widgets in the page and interactive charts.
- Better Async/Actor/Networking code.
- Slots for templates

# Ideas

- Integration with WebComponent, Svelte, React, UI Kits.
- Integration with LiveView, RoR, Laravel solutions for Desktop, IoS, Android.

# Deployment options

Unlike other UI frameworks, it doesn't have any dependency or environment. The UI is just a function that
gets a JSON string as input and respond with a JSON string as output:

```Nim
let out: seq[OutEvent] = component.process(events: seq[InEvent])
```

And so, it could be used in whatever ways and environments: Browser, Desktop, Mobile, Server.

To deploy it you need the **Proxy Adapter** that would connects the `InEvent/OutEvent` messages to an actual
environment, like a Browser.

The Proxy and UI communicate with JSON messages, and could be executed in the same runtime or in
different runtimes on same or different machines.

**Proxy** part could be deployed to Browser as a) **Standalone App** b) **Widget in another App**,
like React.JS or Ruby on Rails.

**UI** part could be deployed to a) Nim **Server** on another machine b) Compiled to **JS or WebAsm** and run in
the same **Browser** with Proxy.

The only difference in deployment options is the network latency if UI and Proxy run in different machines, the
network traffic going to be small as the UI sends only the diffs.

Because all communication happens using JSON messages, the UI state could be saved and restored,
recorded and replayed.

Work stateful or stateless, without the need to occupy server memory between requests.

Persists the UI state between server reloads.

# License

MIT
