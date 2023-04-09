# component.h --------------------------------------------------------------------------------------
import base, ext/url, ./component, ./h

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
type CounterTest = ref object of Component
  count: int
  text:  string

proc init(_: type[CounterTest]): CounterTest =
  CounterTest(text: "some")

proc render(self: CounterTest): HtmlElement =
  h".counter":
    + h"input type=text"
        .bind_to(self.text)
    + h"button"
      .text("+")
      .on_click(proc = (self.count += 1))
    + h""
      .text(fmt"{self.text} {self.count}")

type CounterParentTest = ref object of Component

proc render(self: CounterParentTest): HtmlElement =
  h".parent":
    + self.h(CounterTest, "counter")

test "counter":
  let app = CounterParentTest()

  block: # Rendering initial HTML
    let res = app.process @[]
    # let initial_html =
    #   %{ class: "parent", children: [
    #     { class: "counter", children: [
    #       { tag: "input", value: "some", type: "text" },
    #       { tag: "button", text: "+" },
    #       { text: "some 0" },
    #     ] }
    #   ] }
    # let expected = %[{ kind: "update_element", updates: [ { el: [], set: initial_html } ] }]
    check res.to_html == """
      <div class="parent">
        <div class="counter">
          <input type="text" value="some"/>
          <button>+</button>
          <div>some 0</div>
        </div>
      </div>""".dedent

  block: # Changing input
    let res = app.process @[InEvent(kind: input, el: @[0, 0], input: InputEvent(value: "another"))]
    check:
      app.get_child_component(CounterTest, "counter").CounterTest.text == "another"
      res.is_empty # changing input without listener shouldn't trigger re-render

  block: # Clicking on button
    let res = app.process @[InEvent(kind: click, el: @[0, 1], click: ClickEvent())]
    check: res.to_json == %[{ kind: "update_element", updates: [
      { el: [0,2], set_attrs: { text: "another 1" } }
    ]}]