import basem, jsonm, timem

from jester import nil
from times import nil


# set_cookie ---------------------------------------------------------------------------------------
# By default set expiration in 10 years
proc set_cookie*(
  headers: var seq[(string, string)], key, value: string, expires_in_sec = 10 * 12 * 30.days.seconds
) =
  let expires = times.`+`(times.now(), times.seconds(expires_in_sec))
  let headers_copy = headers
  proc wrapperfn(): jester.ResponseData =
    result.headers = headers_copy.some
    jester.set_cookie(key, value, expires = expires)
  headers = wrapperfn().headers.get


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

# # get_cookies ------------------------------------------------------------------------------------
# proc get_cookies*(headers: Table[string, seq[string]]): Table[string, string] =
#   let raw = headers["Cookie", @[]].join("; ")
#   for k, v in std_cookies.parse_cookies(raw): result[k] = v