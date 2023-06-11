import base, mono/[core, http]

type Hello = ref object of Component
  name: string

proc render(self: Hello): El =
  el"":
    el("input", (autofocus: true), it.bind_to(self.name))
    if not self.name.is_empty:
      el("span", (text: "Hello " & self.name))

when is_main_module:
  run_http_server(() => Hello())