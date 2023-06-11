import base, ext/url
import ../core/[mono_el, component, tmpl, sessionm]

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
    el("button", (text: "+")):
      it.on_click(proc = (self.count += 1))
    el("", (text: fmt"{self.a} {self.b} {self.count}"))

type CounterParent = ref object of Component

proc set_attrs(self: CounterParent) =
  discard

proc render(self: CounterParent): El =
  el".parent":
    self.el(Counter, "counter", ())

test "counter":
  let session = Session.init(CounterParent())
  session.id = "mid"

  block: # Rendering initial HTML
    session.inbox = @[InEvent(kind: location, location: Url.init("/"))]
    check:
      session.process == true
      session.el.get.to_html == """
        <div class="parent" mono_id="mid">
          <div class="counter">
            <input type="text" value="a1"></input>
            <input type="text" value="b1"></input>
            <button on_click="true">+</button>
            <div>a1 b1 0</div>
          </div>
        </div>
      """.dedent.trim

  block: # Changing input, without render
    session.inbox = @[InEvent(kind: input, el: @[0, 0], input: InputEvent(value: "a2"))]
    session.outbox.clear
    check:
      session.process == false # the input changed, but the render will be skipped
      session.app.get_child_component(Counter, "counter").Counter.a == "a2" # binded variable shold be updated

  block: # Changing input, with render
    session.inbox = @[InEvent(kind: input, el: @[0, 1], input: InputEvent(value: "b2"))]
    session.outbox.clear
    check:
      session.process == true
      session.app.get_child_component(Counter, "counter").Counter.b == "b2" # binded variable shold be updated
      session.outbox.to_json == %[{ kind: "update", diffs: [
        ["set_text", [0, 3], "a2 b2 0"]
      ]}]

  block: # Clicking on button, with render
    session.inbox = @[InEvent(kind: click, el: @[0, 2], click: ClickEvent())]
    session.outbox.clear
    check:
      session.process == true
      session.outbox.len == 1
      session.outbox.to_json == %[{ kind: "update", diffs: [
        ["set_text", [0, 3], "a2 b2 1"]
      ]}]