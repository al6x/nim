The `el` template used to build HTML:

```Nim
test "el, basics":
  check:
    el("ul.todos", it.class("editing")).to_html == """<ul class="todos editing"></ul>"""
    el("ul.todos", (class: "editing")).to_html  == """<ul class="todos editing"></ul>"""
    el("ul.todos", (class: "a"), it.class("b")).to_html == """<ul class="todos a b"></ul>"""
    el("", (style: (bg_color: "block"))).to_html == """<div style="bg-color: block;"></div>"""

  let tmpl =
    el".parent":
      el".counter":
        el("input type=text", (value: "some"))
        el("button", (text: "+"))

  check tmpl.to_html == """
    <div class="parent">
      <div class="counter">
        <input type="text" value="some"></input>
        <button>+</button>
      </div>
    </div>""".dedent
```

Same `el` template also used for high-level Components

```Nim
test "el stateful component":
  type Panel = ref object of Component
    color: string
  proc render(self: Panel, content: seq[El]): El = # Feature: render can have optional arg `content`
    el(fmt"panel .{self.color}"):
      it.add content

  proc Button(color: string): El =
    el(fmt"button .{color}")

  type App = ref object of Component
  proc render(self: App): El =
    el"app":
      self.el(Panel, "panel", (color: "blue")):
        el(Button, (color: "blue"))

  check App().render.to_html == """
    <app>
      <panel class="blue">
        <button class="blue"></button>
      </panel>
    </app>
  """.dedent.trim
```

There's simple version of Component, when you don't need the State, to simplify the code the
proc could be used as Component, but it will be stateless:

```Nim
test "el proc component":
  proc Button(color: string): El =
    el(fmt"button .{color}")

  # Feature: proc component can have optional argument `content`
  proc Panel(color: string, size = "small", content: seq[El]): El =
    el(fmt"panel .{color} .{size}"):
      it.add content

  type LRLayout = ref object of Component
    left*, right*: seq[El]
  proc render(self: LRLayout): El =
    el"layout":
      if not self.left.is_empty:
        el"left":
          it.add self.left
      if not self.right.is_empty:
        el"right":
          it.add self.right

  type App = ref object of Component
  proc render(self: App): El =
    let left = els:
      el(Panel, (color: "blue")):
        el(Button, (color: "blue"))
    el"app":
      self.el(LRLayout, (left: left))

  check App().render.to_html == """
    <app>
      <layout>
        <left>
          <panel class="blue small">
            <button class="blue"></button>
          </panel>
        </left>
      </layout>
    </app>
  """.dedent.trim
```