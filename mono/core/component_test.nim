import base, ./el, ./component, ./h

# diff ---------------------------------------------------------------------------------------------
test "diff":
  template tdiff(id, a, b, s) =
    check diff(id, a, b).to_json == s

  tdiff [0], bh("#i.a r", it.text("t1")), bh(".b c", it.text("t0")), %[
    { el:[0], set_attrs: { class: "a", id: "i", r: "true", text: "t1" }, del_attrs: ["c"] }
  ]

  block:
    let a = bh".a2":
      h".b2":
        it.text("bbb2")
      h".c2"
    let b = bh".a1 aa1":
      h".b1 bb1":
        it.text("bbb1")
      h"span.c1"
      h"d1"
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

proc render(self: Counter): El =
  bh".counter":
    h"input type=text":
      it.bind_to(self.a, true) # skipping render on input change
    h"input type=text":
      it.bind_to(self.b)
    h"button":
      it.text("+")
      it.on_click(proc = (self.count += 1))
    h"":
      it.text(fmt"{self.a} {self.b} {self.count}")

type CounterParent = ref object of Component

proc render(self: CounterParent): El =
  bh".parent":
    self.h(Counter, "counter", ())

test "counter":
  let app = CounterParent()

  block: # Rendering initial HTML
    let res = app.process @[]
    check res.initial_root_el.to_html == """
      <div class="parent" mono_id="">
        <div class="counter">
          <input type="text" value="a1"></input>
          <input type="text" value="b1"></input>
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