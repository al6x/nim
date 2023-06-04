import base, std/os
import ../core, ../parse, ../render

test "to_html, basics":
  let text = """
    Some #tag text ^text

    - a
    - b ^list
  """.dedent

  let space_id = "some_space"
  let doc = FDoc.parse(text, "doc.ft")
  let context: FContext = (doc, space_id, FHtmlConfig.init)

  let htmls = doc.sections[0].blocks.map((blk) => blk.to_html(context).to_html)
  check htmls == @[
    """<p>Some <a class="tag" href="/tags/tag">#tag</a> text</p>""",
    "<p>a</p>\n<p>b</p>"
  ]