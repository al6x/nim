# component.h --------------------------------------------------------------------------------------
import base, ext/url, ./html_element, ./component, ./h

type Child1 = ref object of Component
  v1: int

proc init(_: type[Child1]): Child1 = Child1()
proc set_attrs(self: Child1, v1: int): void = self.v1 = v1
proc render(self: Child1): HtmlElement = h".child1"

type Child2 = ref object of Component
  v2: string

proc init(_: type[Child2]): Child2 = Child2()
proc set_attrs(self: Child2, v2: string): void = self.v2 = v2
proc render(self: Child2): seq[HtmlElement] = @[h".child21", h".child22"]

type Parent1 = ref object of Component

proc render(self: Parent1): HtmlElement =
  h".parent":
    + self.h(Child1, "c1", (c: Child1) => c.set_attrs(0))
    + self.h(Child2, "c2", (v2: "some"))

test "component.h":
  let parent = Parent1()
  discard parent.render()


# diff ---------------------------------------------------------------------------------------------
test "diff":
  template tdiff(id, a, b, s) =
    check diff(id, a, b).to_json == s

  tdiff [0], h"#i.a r".text("t1"), h".b c".text("t0"), %[
    { el:[0], set_attrs: { class: "a", id: "i", r: "true", text: "t1" }, del_attrs: ["c"] }
  ]

  block:
    let a = h".a2":
      + h".b2".text("bbb2")
      + h".c2"
    let b = h".a1 aa1":
      + h".b1 bb1".text("bbb1")
      + h"span.c1"
      + h"d1"
    tdiff [0], a, b, %[
      { el: [0], set_attrs: { class: "a2" }, del_attrs: ["aa1"], del_children: [2], set_children: {
        "1": { class: "c2" }
      } },
      { el: [0, 0], set_attrs: { class: "b2", text: "bbb2" }, del_attrs: ["bb1"] }
    ]


# counter ------------------------------------------------------------------------------------------
type Counter = ref object of Component
  count: int
  a: string
  b: string

proc init(_: type[Counter]): Counter =
  Counter(a: "a1", b: "b1")

proc render(self: Counter): HtmlElement =
  h".counter":
    + h"input type=text"
      .bind_to(self.a, true) # skipping render on input change
    + h"input type=text"
      .bind_to(self.b)
    + h"button"
      .text("+")
      .on_click(proc = (self.count += 1))
    + h""
      .text(fmt"{self.a} {self.b} {self.count}")

type CounterParent = ref object of Component

proc render(self: CounterParent): HtmlElement =
  h".parent":
    + self.h(Counter, "counter")

test "counter":
  let app = CounterParent()

  block: # Rendering initial HTML
    let res = app.process @[]
    check res.initial_html_el.to_html == """
      <div class="parent" mono_id="">
        <div class="counter">
          <input type="text" value="a1"/>
          <input type="text" value="b1"/>
          <button on_click="true">+</button>
          <div>a1 b1 0</div>
        </div>
      </div>""".dedent

  block: # Changing input, without render
    let res = app.process @[InEvent(kind: input, el: @[0, 0], input: InputEvent(value: "a2"))]
    check:
      app.get_child_component(Counter, "counter").Counter.a == "a2" # binded variable shold be updated
      res.is_empty # the input changed, but the render will be skipped

  block: # Changing input, with render
    let res = app.process @[InEvent(kind: input, el: @[0, 1], input: InputEvent(value: "b2"))]
    check:
      app.get_child_component(Counter, "counter").Counter.b == "b2" # binded variable shold be updated
      res.to_json == %[{ kind: "update", updates: [
        { el: [0, 3], set_attrs: { text: "a2 b2 0" } }
      ]}]

  block: # Clicking on button, with render
    let res = app.process @[InEvent(kind: click, el: @[0, 2], click: ClickEvent())]
    check res.to_json == %[{ kind: "update", updates: [
      { el: [0, 3], set_attrs: { text: "a2 b2 1" } }
    ]}]



# let initial_html =
#   %{ class: "parent", children: [
#     { class: "counter", children: [
#       { tag: "input", value: "some", type: "text" },
#       { tag: "button", text: "+" },
#       { text: "some 0" },
#     ] }
#   ] }
# let expected = %[{ kind: "update", updates: [ { el: [], set: initial_html } ] }]