import base, ext/[url, html]
export html

type
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
    value*: string
  InputHandler* = proc(e: InputEvent)

  SetValueHandler* = object
    handler*: (proc(v: string))
    delay*:   bool # Performance optimisation, if set to true it won't cause re-render

  MonoElExtras* = ref object of ElExtras
    # on_focus, on_drag, on_drop, on_keypress, on_keyup
    on_click*:    Option[ClickHandler]
    on_dblclick*: Option[ClickHandler]
    on_keydown*:  Option[KeydownHandler]
    on_change*:   Option[ChangeHandler]
    on_blur*:     Option[BlurHandler]
    on_input*:    Option[InputHandler]
    set_value*:   Option[SetValueHandler]

proc get*(self: El, el_path: seq[int]): El =
  result = self
  for i in el_path:
    result = result.children[i]

# window el ----------------------------------------------------------------------------------------
proc window_title*(self: El, title: string) =
  self.attr("window_title", title)

proc window_location*(self: El, location: string | Url) =
  self.attr("window_location", location.to_s)

proc window_title*(el: El): string =
  if "window_title" in el: el["window_title"] else: ""

# events -------------------------------------------------------------------------------------------
proc extras_getset*(self: El): MonoElExtras =
  if self.extras.is_none: self.extras = MonoElExtras().ElExtras.some
  self.extras.get.MonoElExtras

proc extras_get*(self: El): MonoElExtras =
  self.extras.get.MonoElExtras

proc init*(_: type[SetValueHandler], handler: (proc(v: string)), delay: bool): SetValueHandler =
  SetValueHandler(handler: handler, delay: delay)

template bind_to*(element: El, variable, delay) =
  let el = element
  el.value variable

  el.extras_getset.set_value = SetValueHandler.init(
    (proc(v: string) {.closure.} =
      variable = typeof(variable).parse v
      el["value"] = variable.to_s # updating value on the element, to avoid it being detected by diff
    ),
    delay
  ).some

template bind_to*(element: El, variable) =
  bind_to(element, variable, false)

proc on_click*(self: El, fn: proc(e: ClickEvent)) =
  self.attr("on_click", true)
  self.extras_getset.on_click = fn.some

proc on_click*(self: El, fn: proc()) =
  self.attr("on_click", true)
  self.extras_getset.on_click = (proc(e: ClickEvent) = fn()).some

proc on_dblclick*(self: El, fn: proc(e: ClickEvent)) =
  self.attr("on_dblclick", true)
  self.extras_getset.on_dblclick = fn.some

proc on_dblclick*(self: El, fn: proc()) =
  self.attr("on_dblclick", true)
  self.extras_getset.on_dblclick = (proc(e: ClickEvent) = fn()).some

proc on_keydown*(self: El, fn: proc(e: KeydownEvent)) =
  self.attr("on_keydown", true)
  self.extras_getset.on_keydown = fn.some

proc on_change*(self: El, fn: proc(e: ChangeEvent)) =
  self.attr("on_change", true)
  self.extras_getset.on_change = fn.some

proc on_blur*(self: El, fn: proc(e: BlurEvent)) =
  self.attr("on_blur", true)
  self.extras_getset.on_blur = fn.some

proc on_blur*(self: El, fn: proc()) =
  self.attr("on_blur", true)
  self.extras_getset.on_blur = (proc(e: BlurEvent) = fn()).some