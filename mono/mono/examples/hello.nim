import base, mono/[core, http]

type Hello = ref object of Component
  name: string

proc render*(self: Hello): El =
  el"":
    el("input", (autofocus: true, placeholder: "Name..."), it.bind_to(self.name))
    if not self.name.is_empty:
      el("span", (text: "Hello " & self.name))

define_session HelloSession, Hello
run_http_server (url) => HelloSession.init(Hello())