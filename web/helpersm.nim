import ../basem, ../jsonm


# escape_js ----------------------------------------------------------------------------------------
func escape_js(js: string): string =
  js.to_json.replace(re"""^"|"$""", "")

test "escape_js":
  assert escape_js("""); alert("hi there""") == """); alert(\"hi there"""


# escape_html --------------------------------------------------------------------------------------
const ESCAPE_HTML_MAP = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  """: "&quot;",
  """: "&#39;"
}.to_table

func escape_html(html: string): string =
  html.replace(re"""[&<>'"]""", (c) => ESCAPE_HTML_MAP[c])

test "escape_html":
  assert escape_html("<div>") == """&lt;div&gt;"""