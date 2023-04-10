# Features

- Reactive, like Svelte, with compact and clean code.
- Stateful Components.
- Bidirectional data binding to inputs.
- Fast initial page load.
- SEO friendly.
- It's a library, not framework, could be used in multiple ways. In-browser SPA, statefull
  server-side with proxy in browser, stateless server-side, statefull server side but without
  server memory consumption, storing state in serializable session.

# Todo

- Render initial page as HTML for search engines, and for static site HTML?

# Deployment options

It's basically an object with one function that gets input as produces `let out = ui.process(in)` use
input, output and object iself could be serialised and used in whatewer way.

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