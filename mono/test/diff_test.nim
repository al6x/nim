import base, ../core/[mono_el, diff]

template check_diff(id, a, b, expected) =
  check diff(id, a, b).to_json == expected

test "diff, simple":
  check_diff [],
    el(".b d", (text: "t0")),
    el("#i.a r", (text: "t1")),
    %[
      ["set_attrs",[], { class: "a", id: "i", r: true }],
      ["del_attrs",[], ["d"]],
      ["set_text", [], "t1"]
    ]

test "diff, children":
  check_diff [],
    el("a", (el"b1";      el"b2"        )),
    el("a", (el"b1 attr"; el"c2"; el"d2")),
    %[
      ["set_attrs",   [0], { attr: true }],
      ["replace",     [1], el"c2"],
      ["add_children",[],  [el"d2"]]
    ]

test "diff, del":
  check_diff [],
    el("a", (el"b1";      el"b2"; el"b3")),
    el("a", (el"b1 attr"; el"c2"          )),
    %[
      ["set_attrs",        [0], { attr: true }],
      ["replace",          [1], el"c2"],
      ["set_children_len", [],  2]
    ]

test "diff, html":
  check_diff [],
    el("", (html: "<a/>")),
    el("", (html: "<img/>")),
    %[
      ["set_html",[],"<img/>"]
    ]

test "diff, html with structure change replaced with parent":
  check_diff [],
    el("", el""),
    el("", (html: "<img/>")),
    %[
      ["replace", [], el("", (html: "<img/>"))]
    ]

test "diff, nested":
  let a = el".a1 aa1":
    el(".b1 bb1", (text: "bbb1"))
    el"span.c1"
    el"d1"
  let b = el".a2":
    el(".b2", (text: "bbb2"))
    el".c2"
  check_diff [], a, b, %[
    ["set_attrs", [], { class: "a2" }],
    ["del_attrs", [], ["aa1"]],

    ["set_attrs", [0], {class: "b2" }],
    ["del_attrs", [0], ["bb1"]],
    ["set_text",  [0], "bbb2"],

    ["replace", [1], el".c2"],

    ["set_children_len", [], 2]
  ]