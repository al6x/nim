Nim UI/Web/Desktop/Mobile Framework

**High productivity, simple and clean code** are main priorities.

Checkout the [Todo](examples/todo.nim) example or [Video Demo](https://www.youtube.com/watch?v=vjj0mZOh5h4).

# Features

- Reactive, like Svelte, with compact and clean code.
- Works on Nim Server, or Compile to JS in Browser.
- Stateful Components and bidirectional data binding.
- Multiple UI instances with shared memory updated automatically.
- Fast initial page load and SEO friendly.

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

If there's any issues with nimble install, install it manually:

- Download dependencies [base](../base), [ext](../ext), and this library - mono.
- Add all three to Nim build paths.
- Check if `import base, mono/core` works.

Then run [todo example](examples/todo.nim) and start experimenting.

Use `import base/log; log_emitters.len = 0` to silence the default console logger.

# Limitations

I'm using this for a private app, and going to fix bugs as I encounter them.

Some edge cases might not be tested, some HTML inputs haven't been tested.

Currently `-mm:orc` doesn't work, will work with the next Nim release.

# Development and contributing

Checkout the repo, then run

- `nim r mono/test test` for tests.
- `nim r mono/examples/todo` for example.

The whole library is just one function

```Nim
let out: seq[OutEvent] = component.process(events: seq[InEvent])
```

Checkout [core](core), especially the `mono/core/component_test` to see how it works.

Other packages are adapters to connect that function to different environments like Browser or Server.
And provide transport for messages, like HTTP. You could replace it with your own adapter and transport,
like WebSocket.

I use a simple HTTP server and not WebSocket, because I want to avoid dependencies and
keep the code size small, to have fast Nim compilation. You can change that and rewrite server to use WebSocket.

# Todo

- Add screenshots of todo and keep as examples of apps made with mono
- Inherit Component from El, so it.window_title would be possible inside el(Component)
- `document.title` and `document.location`.
- Browser Adapter with multiple widgets in the page and interactive charts.
- Better Async/Actor/Networking code.

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
