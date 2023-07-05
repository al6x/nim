import base, ext/[url, html]
export html

type
  MonoHandler* = tuple[hanlder: proc(event: JsonNode), render: bool] # render - performance optimisation
  MonoElExtras* = ref object of ElExtras
    handlers*: Table[string, seq[MonoHandler]]

  SpecialInputKeys* = enum alt, ctrl, meta, shift

  ClickEvent* = object
    special_keys*: seq[SpecialInputKeys]
  ClickHandler* = proc(e: ClickEvent)

  KeydownEvent* = object
    key*:          string
    special_keys*: seq[SpecialInputKeys]
  KeydownHandler* = proc(e: KeydownEvent)

  ChangeEvent* = object
    stub*: string # otherwise json doesn't work
  ChangeHandler* = proc(e: ChangeEvent)

  BlurEvent* = object
    stub*: string # otherwise json doesn't work
  BlurHandler* = proc(e: BlurEvent)

  InputEvent* = object
    value*: JsonNode
  InputHandler* = proc(e: InputEvent)

proc get*(self: El, el_path: seq[int]): El =
  result = self
  for i in el_path:
    result = result.children[i]

# window el ----------------------------------------------------------------------------------------
proc window_title*(self: El, title: string) =
  self.attr("window_title", title)

proc window_location*(self: El, location: string | Url) =
  self.attr("window_location", location.to_s)

proc window_location*(self: El): Option[Url] =
  if "window_location" in self.attrs: return Url.parse(self.attrs["window_location"].get_str).some

proc window_title*(el: El): string =
  if "window_title" in el.attrs: el.attrs["window_title"].get_str else: ""

proc window_icon*(self: El, icon_href: string) =
  self.attr("window_icon", icon_href)

proc window_icon_disabled*(self: El, icon_href: string) =
  # Will be shown when there's no connection
  self.attr("window_icon_disabled", icon_href)

# events -------------------------------------------------------------------------------------------
proc extras_get*(self: El): MonoElExtras =
  self.extras.get.MonoElExtras

proc on*(self: El, event: string, handler: proc(event: JsonNode), render = true) =
  if self.extras.is_none: self.extras = MonoElExtras().ElExtras.some
  self.attr("on_" & event, if render: "immediate" else: "defer")
  let handlers = self.extras.get.MonoElExtras.handlers
  self.extras.get.MonoElExtras.handlers[event] = handlers.get(event, @[]) & @[(handler, render).MonoHandler]

proc on_click*(self: El, fn: proc(e: ClickEvent), render = true) =
  self.on("click", proc(e: JsonNode) = fn(e.json_to(ClickEvent)), render)

proc on_click*(self: El, fn: proc(), render = true) =
  self.on_click(proc(e: ClickEvent) = fn(), render)

proc on_dblclick*(self: El, fn: proc(e: ClickEvent), render = true) =
  self.on("dblclick", proc(e: JsonNode) = fn(e.json_to(ClickEvent)), render)

proc on_dblclick*(self: El, fn: proc(), render = true) =
  self.on_dblclick(proc(e: ClickEvent) = fn(), render)

proc on_keydown*(self: El, fn: proc(e: KeydownEvent), render = true) =
  self.on("keydown", proc(e: JsonNode) = fn(e.json_to(KeydownEvent)), render)

proc on_change*(self: El, fn: proc(e: ChangeEvent), render = true) =
  self.on("change", proc(e: JsonNode) = fn(e.json_to(ChangeEvent)), render)

proc on_blur*(self: El, fn: proc(e: BlurEvent), render = true) =
  self.on("blur", proc(e: JsonNode) = fn(e.json_to(BlurEvent)), render)

proc on_blur*(self: El, fn: proc(), render = true) =
  self.on_blur(proc(e: BlurEvent) = fn(), render)

proc on_input*(self: El, fn: proc(e: InputEvent), render = true) =
  self.on("input", proc(e: JsonNode) = fn(e.json_to(InputEvent)), render)

proc on_input*(self: El, fn: proc(), render = true) =
  self.on_input(proc(e: InputEvent) = fn(), render)

template bind_to*(element: El, variable: untyped, render: bool) =
  let el = element
  el.value variable

  el.on_input((proc(e: InputEvent) =
    variable = e.value.json_to(typeof(variable))
    el.value variable # updating value on the element, to avoid it being detected by diff
  ), render)

template bind_to*(element: El, variable: untyped) =
  bind_to(element, variable, true)

# template bind_to*(element: El, variable: untyped, render: bool) =
#   let el = element
#   block:
#     let value_s = variable.serialize
#     el.value value_s

#   el.on_input((proc(e: InputEvent) =
#     variable = typeof(variable).parse e.value
#     el.value e.value # updating value on the element, to avoid it being detected by diff
#   ), render)