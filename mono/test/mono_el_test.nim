import base, ../core/mono_el

template check_diff(id, a, b, expected) =
  check diff(id, a, b).to_json == expected

test "diff, simple":
  check_diff [], el(".b c", it.text("t0")), el("#i.a r", it.text("t1")), %[
    { el:[], set_attrs: { class: "a", id: "i", r: "true" }, del_attrs: ["c"] },
    { el:[0], set: { kind: "text", text: "t1" } }
  ]

  check_diff [], el"", html_el("<img/>"), %[
    { el: [], set: { kind: "html", html: "<img/>" } }
  ]

  check_diff [], el"", text_el("some"), %[
    { el: [], set: { kind: "text", text: "some" } }
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
  check_diff [], a, b, %[
    {el: [],    set_attrs: { class: "a2" }, del_attrs: ["aa1"], del_children: [2] },
    {el: [0],   set_attrs: { class: "b2" }, del_attrs: ["bb1"] },
    {el: [0,0], set: { kind: "text", text: "bbb2" } },
    {el: [1],   set: { kind: "el", tag: "div", attrs: { class: "c2" } } }
  ]
