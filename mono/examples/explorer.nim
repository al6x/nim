import base, mono/[core, http]

type Explorer = ref object of Component
  path: string

proc render(self: Explorer): El =
  el"":
    el("input", (autofocus: true, placeholder: "Path..."), it.bind_to(self.path))
    let path = self.path
    if not path.is_empty:
      if fs.exist path:
        if fs.kind(path) == file:
          el("pre", (text: fs.read(path)))
        else:
          for entry in fs.read_dir(path):
            el("", (text: entry.name))
      else:
        el("", (text: fmt"File '{path}' doesn't exist"))

when is_main_module:
  run_http_server(() => Explorer())