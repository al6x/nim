# Deployment options

It's basically an object with one function that gets input as JSON and outputs JSON, and you can
`ui.process(json): json` use it in whatewer way you want.

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

Work as stateless, without need to occupy server memory between requests.

Persist UI state between server reloads.

# Optional Optimisations

Don't send on_change events if no handlers registered.