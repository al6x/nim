del/delete

when compiles

@ is an operator

find/contains

deep_copy

high vs len, x[high(x)]

default, int.default

cmp[int], example sorted(@[4, 2, 6], cmp[int])

is, of, example 2 is int

len = high(T)-low(T)+1

repr

let y = collect(newseq):
  for i in countdown(9, 2, 3):
    i

once, example:
  proc draw(t: Triangle) =
    once:
      graphicsInit()
    line(t.p1, t.p2)
    line(t.p2, t.p3)
    line(t.p3, t.p1)


Use blocks to scope code
block:
  some code
  some code

And also for returning values
let v = block:
  some code
  some code

sizeof({'a'..'z'}) == 32
sizeof(set['a'..'z']) == 4

ast_to_str
expand_macros

current_source_path()

@[1, 2][^1]

var new_tree: El =
  when typeof(rendered) is seq[El]:
    assert rendered.len == 1, "rendered must have exactly one element"
    rendered[0]
  else:
    rendered

template with_session*(s: Session, code) =
  session = s
  defer: session = nil
  code

Checkout strscans

var procs: seq[proc()]
for i, v in [0, 1]:
  capture i, v:
    procs.add proc: echo i