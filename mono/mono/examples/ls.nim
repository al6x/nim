import base, mono/[core, http]

type Ls = ref object of Component
  path: string

proc render*(self: Ls): El =
  el"":
    el("input", (autofocus: true, placeholder: "Path..."), it.bind_to(self.path))
    let path = self.path
    if not path.is_empty:
      if fs.exist path:
        for entry in fs.read_dir(self.path):
          el("", (text: entry.name))
      else:
        el("", (text: fmt"Path '{path}' doesn't exist"))

define_session LsSession, Ls
run_http_server (url) => LsSession.init(Ls())
