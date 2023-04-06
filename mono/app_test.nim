# component.h --------------------------------------------------------------------------------------
import base, ./app, ./h

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