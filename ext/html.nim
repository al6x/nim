import base

# type SafeHtml* = distinct string # not working, Nim crashes https://github.com/nim-lang/Nim/issues/21800
type SafeHtml* = object
  html: string
converter safe_html_to_s*(s: SafeHtml): string = s.html

proc to*(html: string, _: type[SafeHtml]): SafeHtml =
  SafeHtml(html: html)

const ESCAPE_HTML_MAP = { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }.to_table

proc escape_html*(html: string): SafeHtml =
  html.replace(re"""([&<>'"])""", (c) => ESCAPE_HTML_MAP[c]).to(SafeHtml)

test "escape_html":
  check escape_html("""<div attr="val">""").to_s == "&lt;div attr=&quot;val&quot;&gt;"

proc escape_js*(js: string): SafeHtml =
  js.to_json.to_s.replace(re"""^"|"$""", "").to(SafeHtml)

test "escape_js":
  assert escape_js("""); alert("hi there""") == """); alert(\"hi there"""