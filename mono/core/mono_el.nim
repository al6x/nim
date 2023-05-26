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

  UpdateEl* = ref object
    el*:           seq[int]
    set*:          Option[El]
    set_attrs*:    Option[Table[string, string]]
    del_attrs*:    Option[seq[string]]
    set_children*: Option[Table[string, El]]
    del_children*: Option[seq[int]]

proc is_empty*(u: UpdateEl): bool =
  u.set.is_empty and u.set_attrs.is_empty and u.del_attrs.is_empty and u.set_children.is_empty and
    u.del_children.is_empty

proc get*(self: El, el_path: seq[int]): El =
  result = self
  for i in el_path:
    result = result.children[i]

# to_html ------------------------------------------------------------------------------------------
proc window_title*(el: El): string =
  # assert el.kind == JObject, "to_html element data should be JObject"
  # if "window_title" in el: el["window_title"].get_str else: ""
  if "window_title" in el: el["window_title"] else: ""

# attrs --------------------------------------------------------------------------------------------
proc window_title*(self: El, title: string) =
  self.attr("window_title", title)

proc window_location*(self: El, location: string | Url) =
  self.attr("window_location", location.to_s)

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

# diff ---------------------------------------------------------------------------------------------
proc diff(id: seq[int], oel, nel: El, updates: var seq[UpdateEl]) =
  let update = UpdateEl(el: id)
  updates.add update

  if oel.kind != nel.kind: # different kind
    update.set = nel.some

  else: # same kind
    case oel.kind

    of ElKind.el: # el
      if oel.tag != nel.tag: # tag
        update.set = nel.some
      else:
        if oel.attrs != nel.attrs: # attrs
          let (oattrs, nattrs) = (oel.normalise_attrs, nel.normalise_attrs)

          var set_attrs: Table[string, string]
          for k, v in nattrs:
            if k notin oattrs or v != oattrs[k]: set_attrs[k] = v
          unless set_attrs.is_empty: update.set_attrs = set_attrs.some

          var del_attrs: seq[string]
          for k, v in oattrs:
            if k notin nattrs:
              del_attrs.add k
          unless del_attrs.is_empty: update.del_attrs = del_attrs.some

        block: # children
          var set_children: Table[string, El]
          for i, nchild in nel.children:
            if i > oel.children.high:
              set_children[$i] = nchild
            else:
              let ochild = oel.children[i]
              diff(id & [i], ochild, nchild, updates)
          unless set_children.is_empty: update.set_children = set_children.some

          var del_children: seq[int]
          if nel.children.len < oel.children.len:
            del_children = ((nel.children.high + 1)..oel.children.high).to_seq
          unless del_children.is_empty: update.del_children = del_children.some

    of ElKind.text: # text
      if oel.text_data != nel.text_data: update.set = nel.some

    of ElKind.html: # html
      if oel.html_data != nel.html_data: update.set = nel.some

    of ElKind.list: # list
      throw "diff for el.list is not implemented"

proc diff*(id: openarray[int], oel, nel: El): seq[UpdateEl] =
  diff(id.to_seq, oel, nel, result)
  result.reject(is_empty)