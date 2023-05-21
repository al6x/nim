import base, ./parse, ext/html

type
  # Embed are things like `text image{some.png} text`
  EmbedToHtml*  = proc(text: string, parsed: Option[JsonNode], doc: FDoc): safe_html

  FTextHtmlConfig* = ref object
    embeds*: Table[string, EmbedToHtml]
    link*:   proc (text: string, link: FLink, doc: FDoc): safe_html
    glink*:  proc (text, link: string, doc: FDoc): safe_html
    tag*:    proc (tag: string, doc: FDoc): safe_html

proc link(text: string, link: FLink, doc: FDoc): safe_html =
  let target = (if link.space == ".": doc.id else: link.space) & "/" & link.doc
  fmt"""<a class="link" href="{target.escape_html}">{text.escape_html}</a>""".safe_html

proc tag(tag: string, doc: FDoc): safe_html =
  fmt"""<a class="tag" href="/tags/{tag.escape_html}">#{tag.escape_html}</a>""".safe_html

proc glink(text, link: string, doc: FDoc): safe_html =
  fmt"""<a class="glink" href="{link.escape_html}">{text.escape_html}</a>""".safe_html

proc embed_image(text: string, parsed: Option[JsonNode], doc: FDoc): safe_html =
  let target = doc.id & "/" & text
  fmt"""<img src="{target.escape_html}"/>""".safe_html

proc embed_code(text: string, parsed: Option[JsonNode], doc: FDoc): safe_html =
  fmt"""<code>{text.escape_html}</code>""".safe_html

proc init*(_: type[FTextHtmlConfig]): FTextHtmlConfig =
  var embeds: Table[string, EmbedToHtml]
  embeds["image"] = embed_image
  embeds["code"]  = embed_code
  FTextHtmlConfig(embeds: embeds, link: link, glink: glink, tag: tag)

let default_config = FTextHtmlConfig.init

# to_html ------------------------------------------------------------------------------------------
proc to_html*(text: seq[FTextItem], doc: FDoc, config = default_config): safe_html =
  var html = ""

  var em = false
  for i, item in text:
    if   not em and item.em == true:
      em = true; html.add "<b>"
    elif em and item.em != true:
      em = false; html.add "</b>"

    if i != 0: html.add " "

    case item.kind
    of FTextItemKind.text:
      html.add item.text.escape_html
    of FTextItemKind.link:
      html.add config.link(item.text, item.link, doc)
    of FTextItemKind.glink:
      html.add config.glink(item.text, item.glink, doc)
    of FTextItemKind.tag:
      html.add config.tag(item.text, doc)
    of FTextItemKind.embed:
      html.add:
        if item.embed_kind in config.embeds:
          let embed = config.embeds[item.embed_kind]
          embed(item.text, item.parsed, doc)
        else:
          embed_code(item.embed_kind & "{" & item.text & "}", JsonNode.none, doc)

  if em:
    html.add "</b>"
  html.safe_html

proc to_html*(blk: FTextBlock, doc: FDoc, config = default_config): safe_html =
  var html = ""
  for i, pr in blk.formatted_text:
    case pr.kind
    of text:
      html.add "<p>" & pr.text.to_html(doc, config) & "</p>"
    of list:
      html.add "<ul>\n"
      for j, list_item in pr.list:
        html.add "  <li>" & list_item.to_html(doc, config) & "</li>"
        if j < pr.list.high: html.add "\n"
      html.add "</ul>"
    if i < blk.formatted_text.high: html.add "\n"
  html.safe_html

proc to_html*(blk: FListBlock, doc: FDoc, config = default_config): safe_html =
  var html = ""
  for i, list_item in blk.list:
    html.add "<p>" & list_item.to_html(doc, config) & "</p>"
    if i < blk.list.high: html.add "\n"
  html.safe_html

test "to_html":
  let text = """
    Some #tag text ^text

    - a
    - b ^list
  """.dedent

  let doc = parse_ftext(text, "doc.ft")
  let tb = doc.sections[0].blocks[0].FTextBlock
  let lb = doc.sections[0].blocks[1].FListBlock

  check tb.to_html(doc) == """<p>Some <a class="tag" href="/tags/tag">#tag</a> text</p>"""
  check lb.to_html(doc) == "<p>a</p>\n<p>b</p>"