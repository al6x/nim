import base, ext/html, ./core

export core

type
  # Embed are things like `text image{some.png} text`
  FEmbedContext* = tuple[blk: FBlock, doc: FDoc, space_id: string]

  FEmbedToHtml*  = proc(text: string, parsed: Option[JsonNode], context: FEmbedContext): SafeHtml

  FTextHtmlConfig* = ref object
    embeds*: Table[string, FEmbedToHtml]
    link*:   proc (text: string, link: FLink, context: FEmbedContext): SafeHtml
    glink*:  proc (text, link: string, context: FEmbedContext): SafeHtml
    tag*:    proc (tag: string, context: FEmbedContext): SafeHtml

proc link(text: string, link: FLink, context: FEmbedContext): SafeHtml =
  let target = "/" & (if link.space == ".": context.space_id else: link.space) & "/" & link.doc
  fmt"""<a class="link" href="{target.escape_html}">{text.escape_html}</a>"""

proc tag(tag: string, context: FEmbedContext): SafeHtml =
  fmt"""<a class="tag" href="/tags/{tag.escape_html}">#{tag.escape_html}</a>"""

proc glink(text, link: string, context: FEmbedContext): SafeHtml =
  fmt"""<a class="glink" href="{link.escape_html}">{text.escape_html}</a>"""

proc embed_image(text: string, parsed: Option[JsonNode], context: FEmbedContext): SafeHtml =
  let target = "/" & context.space_id & "/" & context.doc.id & "/" & text
  fmt"""<img src="{target.escape_html}"/>"""

proc embed_code(text: string, parsed: Option[JsonNode], context: FEmbedContext): SafeHtml =
  fmt"""<code>{text.escape_html}</code>"""

proc init*(_: type[FTextHtmlConfig]): FTextHtmlConfig =
  var embeds: Table[string, FEmbedToHtml]
  embeds["image"] = embed_image
  embeds["code"]  = embed_code
  FTextHtmlConfig(embeds: embeds, link: link, glink: glink, tag: tag)

let default_config = FTextHtmlConfig.init

# to_html ------------------------------------------------------------------------------------------
proc to_html*(text: seq[FTextItem], context: FEmbedContext, config = default_config): SafeHtml =
  var html = ""

  var em = false
  for i, item in text:
    if   not em and item.em == true:
      em = true; html.add "<b>"
    elif em and item.em != true:
      em = false; html.add "</b>"

    case item.kind
    of FTextItemKind.text:
      html.add item.text.escape_html
    of FTextItemKind.link:
      html.add config.link(item.text, item.link, context)
    of FTextItemKind.glink:
      html.add config.glink(item.text, item.glink, context)
    of FTextItemKind.tag:
      html.add config.tag(item.text, context)
    of FTextItemKind.embed:
      html.add:
        if item.embed_kind in config.embeds:
          let embed = config.embeds[item.embed_kind]
          embed(item.text, item.parsed, context)
        else:
          embed_code(item.embed_kind & "{" & item.text & "}", JsonNode.none, context)

  if em:
    html.add "</b>"
  html

proc to_html*(blk: FTextBlock, doc: FDoc, space_id: string, config = default_config): SafeHtml =
  let context: FEmbedContext = (blk, doc, space_id)
  var html = ""
  for i, pr in blk.formatted_text:
    case pr.kind
    of text:
      html.add "<p>" & pr.text.to_html(context, config) & "</p>"
    of list:
      html.add "<ul>\n"
      for j, list_item in pr.list:
        html.add "  <li>" & list_item.to_html(context, config) & "</li>"
        if j < pr.list.high: html.add "\n"
      html.add "</ul>"
    if i < blk.formatted_text.high: html.add "\n"
  html

proc to_html*(blk: FListBlock, doc: FDoc, space_id: string, config = default_config): SafeHtml =
  let context: FEmbedContext = (blk, doc, space_id)
  var html = ""
  for i, list_item in blk.list:
    html.add "<p>" & list_item.to_html(context, config) & "</p>"
    if i < blk.list.high: html.add "\n"
  html