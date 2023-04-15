UI library for Nim.

**High productivity, simple and clean code** are main priorities.

Checkout the [Todo](examples/todo.nim) example.

# Features

- Reactive, like Svelte, with compact and clean code.
- Stateful Components.
- Bidirectional data binding to inputs.
- Multiple UI instances with shared memory updated automatically.
- Fast initial page load.
- SEO friendly.
- Flexible deployment: Server, Browser, Desktop, Mobile.

# Install

`nimble install https://github.com/al6x/nim?subdir=mono`

If there's any issues with nimble install, install it manually:

- Download two libraries [base](../base) and this library - mono.
- Add both to nim build paths.
- Check if code `import base, mono/core` works.

Then run [todo example](examples/todo.nim) and start experimenting.

# Limitations

Some edge cases may not be tested, some HTML inputs haven't been tested, so there could be bugs.

I'm using it to build some private app, and going to fix bugs as I'll encounter it... :)

# Development and contribuging

Checkout the repo, then run

- `nim r mono/test test` for tests.
- `nim r mono/examples/todo` for example.

The whole library is just one function

```
let out: seq[OutEvent] = component.process(events: seq[InEvent])
```

Checkout [core](core), especially the `mono/core/component_test` to see how it works.

# Todo

- document.title and document.location
- Browser Adapter with multiple widgets in the page and interactive charts.
- Better Async/Actor/Networking code.

# Deployment options

Unline other UI frameworks it doesn't have any dependency or environment. The UI is just a function that
get JSON string as input and respond with JSON string as output:

```
let out: seq[OutEvent] = component.process(events: seq[InEvent])
````

And so it could be used in whatever ways and environments Browser, Desktop, Mobile, Server.

To deploy it you need the **Proxy Adapter** that would connects the `InEvent/OutEvent` messages to actual
environment, like Browser.

The Proxy and UI are communicate with JSON messages, and could be executed in the same runtime or in
different runtimes on same or different machines.

**Proxy** part could be deployed to Browser as a) **Standalone App** b) **Widget in another App**,
like React.JS or Ruby on Rails.

**UI** part could be deplyed to a) Nim **Server** on another machine b) Compiled to **JS or WebAsm** and run in
the same **Browser** with Proxy.

The only difference in deployment options is network latency if UI and Proxy run in different machiens, the
network traffic going to be small as UI sends only diffs.

Because all communication happens as JSON messages, the UI state could be saved and reestored,
recorded and replayed.

Work as statefull or stateless, without need to occupy server memory between requests.

Persist UI state between server reloads.