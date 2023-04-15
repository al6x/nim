UI library for Nim, similar to Svelte.

**High productivity, simple and clean code** are main priorities.

Checkout the [Todo](examples/todo.nim) example.

# Features

- Reactive, like Svelte, with compact and clean code.
- Stateful Components.
- Bidirectional data binding to inputs.
- Fast initial page load.
- SEO friendly.
- Lots of deployment options, Browser, Desktop, Mobile, Server.

# Install

`nimble install https://github.com/al6x/nim?subdir=mono`

If there's any issues with nimble install, install it manually, download two libraries
[base](../base) and this library - mono, add to nim build paths and check if
code `import base, mono/core` works.

# Limitations

Some edge cases may not be tested.

# Development and contribuging

Checkout the repo, then run

- `nim r mono/test test` for tests.
- `nim r mono/examples/todo` for example.

Checkout code in the `mono/core` folder, especially the `mono/core/component_test` to understand how it works.

# Todo

- document.title and document.location
- Browser Adapter with multiple widgets in the page and interactive charts.
- Twitter exapmle and Chat example.
- Better Async/Actor/Networking code.

# Deployment options

Unline other UI frameworks it doesn't requires any dependency or environment. It's just a function that
get JSON string as input and respond with JSON string as output `let out = ui.process(in)`. So it could
be used in whatever ways and environments Browser, Desktop, Mobile, Server.

UI has two parts, the **UI itself**, the actual UI running Nim code, and the **Proxy View** that has no
code or logic and just renders the HTML it gets as string from the actual UI.

The Proxy and UI are communicate with JSON messages, and could be executed in the same runtime or in
different runtimes on same or different machines.

**Proxy View** part could be deployed to Browser as a) **Standalone App** b) **Widget in another App**,
like React.JS or Ruby on Rails.

**UI** part could be deplyed to a) Nim **Server** on another machine b) Compiled to **JS or WebAsm** and run in
the same **Browser** with Proxy View.

The only difference in deployment options is network latency if UI and Proxy run in different machiens, the
network traffic going to be small as UI sends only diffs.

Because all communication happens as JSON messages, the UI state could be saved and reestored,
recorded and replayed.

Work as statefull or stateless, without need to occupy server memory between requests.

Persist UI state between server reloads.