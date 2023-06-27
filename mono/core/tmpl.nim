import std/macros
import base, ./component, ./mono_el, ./macro_helpers

export macro_helpers

# component el -------------------------------------------------------------------------------------
template build_el*[T: Component](parent: Component, ChildT: type[T], id: string | int, attrs: tuple, code): El =
  let attrsv = attrs
  let component = parent.get(ChildT, id, attrs)
  let content = els(code)
  render(component, content)

template build_el*[T: Component](parent: Component, ChildT: type[T], id: string | int, attrs: tuple): El =
  let attrsv = attrs
  let component = parent.get(ChildT, id, attrs)
  render(component)

template build_el*[T: Component](parent: Component, ChildT: type[T], attrs: tuple, code): El =
  build_el(parent, ChildT, "", attrs, code)

template build_el*[T: Component](parent: Component, ChildT: type[T], attrs: tuple): El =
  build_el(parent, ChildT, "", attrs)

template el*[T: Component](parent: Component, ChildT: type[T], id: string | int, attrs: tuple, code): auto =
  add_or_return_el build_el(parent, ChildT, id, attrs, code)

template el*[T: Component](parent: Component, ChildT: type[T], id: string | int, attrs: tuple): auto =
  add_or_return_el build_el(parent, ChildT, id, attrs)

template el*[T: Component](parent: Component, ChildT: type[T], attrs: tuple, code): auto =
  add_or_return_el build_el(parent, ChildT, attrs, code)

template el*[T: Component](parent: Component, ChildT: type[T], attrs: tuple): auto =
  add_or_return_el build_el(parent, ChildT, attrs)

# proc component el --------------------------------------------------------------------------------
template build_el*(fn: proc, attrs: tuple, code): El =
  let attrsv = attrs
  let content = els(code)
  var el: El
  call_fn_with_content_r(fn, attrsv, content, el)
  el

template build_el*(fn: proc, attrs: tuple): El =
  let attrsv = attrs
  var el: El
  call_fn_r(fn, attrsv, el)
  el

template el*(fn: proc, attrs: tuple, code): auto =
  add_or_return_el build_el(fn, attrs, code)

template el*(fn: proc, attrs: tuple): auto =
  add_or_return_el build_el(fn, attrs)

# alter --------------------------------------------------------------------------------------------
template alter_el*(el_expression, code): auto =
  let el_to_alter = block:
    var it {.inject.} = seq[El].init
    el_expression
    assert it.len == 1
    it[0]
  block:
    var it {.inject.} = el_to_alter
    code
  add_or_return_el el_to_alter
