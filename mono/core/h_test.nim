import base, ./component, ./html_element, ./h


test "build_el":
  let html = build_h"ul.c1":
    for text in @["t1"]:
      h"li.c2":
        it.attr("class", "c3")
        it.text(text)
        it.on_click(proc (e: auto) = discard)

  check html.to_html == """
    <ul class="c1">
      <li class="c2 c3" on_click="true">t1</li>
    </ul>
  """.dedent.trim


test "build_component":
  type Panel = ref object of Component
    color:   string
    content: HtmlElement
  proc render(self: Panel): HtmlElement =
    build_h"panel .{self.color}":
      it.children.add self.content

  type Button = ref object of Component
    color: string
  proc render(self: Button): HtmlElement =
    build_h"button .{self.color}"

  type App = ref object of Component
  proc render(self: App): HtmlElement =
    build_h"app":
      h(Panel, (color: "blue")):
        it.content = build_h(Button, (color: "blue"))

  let root_el = build_h(App, (color: "blue"))
  check root_el.to_html == """
    <app>
      <panel class="blue">
        <button class="blue"></button>
      </panel>
    </app>
  """.dedent.trim


test "build_proc_component":
  proc button(color: string): HtmlElement =
    build_h"button .{color}"

  type App = ref object of Component
  proc render(self: App): HtmlElement =
    build_h"app":
      h(button, (color: "blue"))

  let root_el = build_h(App, (color: "blue"))
  check root_el.to_html == """
    <app>
      <button class="blue"></button>
    </app>
  """.dedent.trim


test "build_stateful_scomponent":
  type Panel = ref object of Component
    color:   string
    content: HtmlElement
  proc render(self: Panel): HtmlElement =
    build_h"panel .{self.color}":
      it.children.add self.content

  type Button = ref object of Component
    color: string
  proc render(self: Button): HtmlElement =
    build_h"button .{self.color}"

  type App = ref object of Component
  proc render(self: App): HtmlElement =
    build_h"app":
      self.h(Panel, "panel", (color: "blue")):
        it.content = build_h(Button, (color: "blue"))

  let root_el = build_h(App, (color: "blue"))
  check root_el.to_html == """
    <app>
      <panel class="blue">
        <button class="blue"></button>
      </panel>
    </app>
  """.dedent.trim