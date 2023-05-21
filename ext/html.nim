import base

type safe_html* = distinct string
converter safe_html_to_s*(s: safe_html): string = s.string

const ESCAPE_HTML_MAP = { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }.to_table

proc escape_html*(html: string): safe_html =
  html.replace(re"""([&<>'"])""", (c) => ESCAPE_HTML_MAP[c]).safe_html

test "escape_html":
  check escape_html("""<div attr="val">""").to_s == "&lt;div attr=&quot;val&quot;&gt;"

proc escape_js*(js: string): safe_html =
  js.to_json.to_s.replace(re"""^"|"$""", "").safe_html

test "escape_js":
  assert escape_js("""); alert("hi there""") == """); alert(\"hi there"""