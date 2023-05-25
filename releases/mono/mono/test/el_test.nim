import base, ../core/el

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