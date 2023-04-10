# Features

- Reactive, like Svelte, with compact and clean code.
- Stateful Components.
- Bidirectional data binding to inputs.
- Fast initial page load.
- SEO friendly.
- Lots of deployment options, Browser, Desktop, Mobile, Server.

# Todo

- Render initial page as HTML for search engines, and for static site HTML?

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

# Optional Optimisations

Don't send on_change events if no handlers registered.