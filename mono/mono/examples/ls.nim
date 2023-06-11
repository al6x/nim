import base, mono/[core, http]

type Ls = ref object of Component
  path: string

proc render(self: Ls): El =
  el"":
    el("input", (autofocus: true, placeholder: "Path..."), it.bind_to(self.path))
    if not self.path.is_empty:
      if fs.exist self.path:
        for entry in fs.read_dir(self.path):
          el("", (text: entry.name))
      else:
        el("", (text: fmt"Path '{self.path}' doesn't exist"))

when is_main_module:
  run_http_server(proc (url: Url): auto = Session.init(Ls()))