proc to_meta_html*(el: JsonNode): tuple[meta, html: string] =
  # If the root element is "document", excluding it from the HTML
  assert el.kind == JObject, "to_html element data should be JObject"
  let tag = if "tag" in el: el["tag"].get_str else: "div"
  var meta: seq[string]
  if tag == "document":
    if "title" in el:
      meta.add "<title>" & el["title"].get_str.escape_html_text & "</title>"
    if "location" in el:
      meta.add "<meta name=\"location\" content=" & el["location"].escape_html_attr_value & "/>"
    let children = el["children"]
    assert children.kind == JArray, "to_html element children should be JArray"
    (meta.join("\n"), children.to_seq.map((el) => el.to_html).join("\n"))
  else:
    (meta.join("\n"), el.to_html)

test "to_meta_html":
  let el = %{ tag: "document", title: "some", children: [
    { class: "counter" }
  ] }
  check el.to_meta_html == (
    meta: """<title>some</title>""",
    html: """<div class="counter"></div>"""
  )

proc to_html(meta: HtmlMeta): string =
  var tags: seq[string]
  if not meta.title.is_empty:
    tags.add "<meta name=\"title\" content=" & meta.title.escape_html_attr_value & "/>"
  tags.join("\n")

proc to_meta_html*(el: JsonNode): tuple[meta, html: string] =
  let (html, document) = el.to_html_and_document
  (meta: document.document_to_meta, html: html)



# template h*[T](self: Component, ChildT: type[T], id: string): seq[HtmlElement] =
#   self.h(ChildT, id, proc(c: T) = (discard))



# document_h ---------------------------------------------------------------------------------------
# template document_h*(title: string, location: Url, code): HtmlElement =
#   h"document":
#     discard it.attr("title", title)
#     discard it.attr("location", location)
#     code

# test "document_h":
#   let html = document_h("t1", Url.init("/a")):
#     + h"div"
#   check html.to_json == """{"title":"t1","location":"/a","tag":"document","children":[{"tag":"div"}]}""".parse_json

# h ------------------------------------------------------------------------------------------------
# converter to_html_elements*(el: HtmlElement): seq[HtmlElement] =
#   # Needed to return single or multiple html elements from render
#   @[el]

# template content*(el: HtmlElement): HtmlElement =
#   el

# template content*(el: HtmlElement, code): HtmlElement =
#   let node = el
#   block:
#     let it {.inject.} = node
#     code
#   node

# test "h":
#   let html = h".blog".window_title("Blog").content:
#     + h".posts"

#   check html.to_html == """
#     <div class="blog" window_title="Blog">
#       <div class="posts"></div>
#     </div>
#   """.dedent.trim