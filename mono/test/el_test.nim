import base, ext/html, ../core/el

test "parse_tag":
  template check_attrs(tag: string, expected) =
    check parse_tag(tag) == expected.to_table

  check_attrs "span#id.c-1.c2 .c3  .c-4 type=checkbox required", {
    "tag": "span", "id": "id", "class": "c-1 c2 c3 c-4", "type": "checkbox", "required": "true"
  }
  check_attrs "span",     { "tag": "span" }
  check_attrs "#id",      { "id": "id" }
  check_attrs ".c-1",     { "class": "c-1" }
  check_attrs "div  a=b", { "tag": "div", "a": "b" }
  check_attrs " .a  a=b", { "class": "a", "a": "b" }
  check_attrs " .a",      { "class": "a" }

  check_attrs "$controls .a",     { "c": "controls", "class": "a" }
  check_attrs "$controls.a",      { "c": "controls", "class": "a" }
  check_attrs "button$button.a",  { "tag": "button", "c": "button", "class": "a" }

test "nattrs":
  check El.init(tag = "ul.todos", attrs = (class: "editing").to_json).nattrs ==
    """{"class":"todos editing","tag":"ul"}""".parse_json

test "to_html":
  let el = %{ class: "parent", children: [
    { class: "counter", children: [
      { tag: "input", value: "some", type: "text" },
      { tag: "button", text: "+" },
    ] }
  ] }
  let html = """
    <div class="parent">
      <div class="counter">
        <input type="text" value="some"></input>
        <button>+</button>
      </div>
    </div>""".dedent
  check el.to_html == html

  check El.init.to_html == "<div></div>"

  check (%{ text: 0 }).to_html == "<div>0</div>" # from error