import base, ../core/[el, component, tmpl]

# diff ---------------------------------------------------------------------------------------------
template diff(id, a, b, s) =
  check diff(id, a, b).to_json == s

test "diff, simple":
  diff [], el(".b c", it.text("t0")), el("#i.a r", it.text("t1")), %[
    { el:[], set_attrs: { class: "a", id: "i", r: "true", text: "t1" }, del_attrs: ["c"] }
  ]

test "diff, nested":
  let a = el".a1 aa1":
    el".b1 bb1":
      it.text("bbb1")
    el"span.c1"
    el"d1"
  let b = el".a2":
    el".b2":
      it.text("bbb2")
    el".c2"
  diff [], a, b, %[
    { el: [], set_attrs: { class: "a2" }, del_attrs: ["aa1"], del_children: [2], set_children: {
      "1": { class: "c2" }
    } },
    { el: [0], set_attrs: { class: "b2", text: "bbb2" }, del_attrs: ["bb1"] }
  ]

# counter ------------------------------------------------------------------------------------------
type Counter = ref object of Component
  count: int
  a: string
  b: string

proc set_attrs(self: Counter) =
  discard

proc init(_: type[Counter]): Counter =
  Counter(a: "a1", b: "b1")

proc render(self: Counter): El =
  el".counter":
    el"input type=text":
      it.bind_to(self.a, true) # skipping render on input change
    el"input type=text":
      it.bind_to(self.b)
    el"button":
      it.text("+")
      it.on_click(proc = (self.count += 1))
    el"":
      it.text(fmt"{self.a} {self.b} {self.count}")

type CounterParent = ref object of Component

proc set_attrs(self: CounterParent) =
  discard

proc render(self: CounterParent): El =
  el".parent":
    self.el(Counter, "counter", ())

test "counter":
  let app = CounterParent()

  block: # Rendering initial HTML
    let res = app.process @[]
    check res.initial_root_el.to_html == """
      <div class="parent" mono_id="">
        <div class="Counter C counter">
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