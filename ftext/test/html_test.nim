import base
import ../core, ../parse, ../html

test "to_html":
  let text = """
    Some #tag text ^text

    - a
    - b ^list
  """.dedent

  let doc = FDoc.parse(text, "doc.ft")
  let tb = doc.sections[0].blocks[0].FTextBlock
  let lb = doc.sections[0].blocks[1].FListBlock

  check tb.to_html(doc, "space") == """<p>Some <a class="tag" href="/tags/tag">#tag</a> text</p>"""
  check lb.to_html(doc, "space") == "<p>a</p>\n<p>b</p>"