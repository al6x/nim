import base, ../core/[mono_el, component, tmpl]

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
    let expected = """
      <div class="parent" mono_id="">
        <div class="counter">
          <input type="text" value="a1"></input>
          <input type="text" value="b1"></input>
          <button on_click="true">+</button>
          <div>a1 b1 0</div>
        </div>
      </div>""".dedent
    check res.initial_root_el.to_html == expected

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
        { el: [0, 3, 0], set: { kind: "text", text: "a2 b2 0" } }
      ]}]

  block: # Clicking on button, with render
    let res = app.process @[InEvent(kind: click, el: @[0, 2], click: ClickEvent())]
    check res.to_json == %[{ kind: "update", updates: [
      { el: [0, 3, 0], set: { kind: "text", text: "a2 b2 1" } }
    ]}]