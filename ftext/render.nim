import base, ext/html, ./core, std/os

export core, html

type
  # Embed are things like `text image{some.png} text`
  FContext* = tuple[doc: FDoc, space_id: string, config: FHtmlConfig]

  FEmbedToHtml*  = proc(text: string, parsed: Option[JsonNode], context: FContext): SafeHtml

  FHtmlConfig* = ref object
    embeds*:     Table[string, FEmbedToHtml]
    link_path*:  proc (link: FLink, context: FContext): string
    tag_path*:   proc (tag: string, context: FContext): string
    image_path*: proc (path: string, context: FContext): string

# config -------------------------------------------------------------------------------------------
proc link_path(link: FLink, context: FContext): string =
  "/" & (if link.space == ".": context.space_id else: link.space) & "/" & link.doc

proc tag_path(tag: string, context: FContext): string =
  fmt"/tags/{tag.escape_html}"

proc embed_image(text: string, parsed: Option[JsonNode], context: FContext): SafeHtml =
  let path = context.config.image_path(text, context)
  fmt"""<img src="{path.escape_html}"/>"""

proc embed_code(text: string, parsed: Option[JsonNode], context: FContext): SafeHtml =
  fmt"""<code>{text.escape_html}</code>"""

proc image_path(path: string, context: FContext): string =
  "/" & context.space_id & "/" & context.doc.id & "/" & path

proc init*(_: type[FHtmlConfig]): FHtmlConfig =
  var embeds: Table[string, FEmbedToHtml]
  embeds["image"] = embed_image
  embeds["code"]  = embed_code
  FHtmlConfig(embeds: embeds, link_path: link_path, tag_path: tag_path, image_path: image_path)

# to_html ------------------------------------------------------------------------------------------
# base block
method to_html*(blk: FBlock, context: FContext): El {.base.} =
  el".border-l-4.border-orange-800 .text-orange-800":
    el".text-orange-800 .ml-2":
      it.text fmt"to_html not defined for {blk.raw.kind} block"

# section
proc to_html*(section: FSection, context: FContext): El =
  el".text-xl":
    it.text section.title

# subsection
method to_html*(blk: FSubsection, context: FContext): El =
  el".text-lg":
    it.text blk.title

# text items
proc to_html*(text: seq[FTextItem], context: FContext): SafeHtml =
  var html = ""; let config = context.config

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
      let path = config.link_path(item.link, context)
      html.add fmt"""<a class="link" href="{path.escape_html}">{item.text.escape_html}</a>"""
    of FTextItemKind.glink:
      html.add fmt"""<a class="glink" href="{item.glink.escape_html}">{item.text.escape_html}</a>"""
    of FTextItemKind.tag:
      let path = config.tag_path(item.text, context)
      html.add fmt"""<a class="tag" href="/tags/{item.text.escape_html}">#{item.text.escape_html}</a>"""
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

# text
method to_html*(blk: FTextBlock, context: FContext): El =
  list_el:
    for i, pr in blk.formatted_text:
      case pr.kind
      of FParagraphKind.text:
        el "p":
          it.html pr.text.to_html(context)
      of FParagraphKind.list:
        el "ul":
          for list_item in pr.list:
            el "li":
              it.html list_item.to_html(context)

# list
method to_html*(blk: FListBlock, context: FContext): El =
  list_el:
    for list_item in blk.list:
      el "p":
        it.html list_item.to_html(context)

# code
method to_html*(blk: FCodeBlock, context: FContext): El =
  el"pre":
    it.text blk.code.escape_html

# image
method to_html*(blk: FImageBlock, context: FContext): El =
  let path = context.config.image_path(blk.image, context)
  el"img":
    it.attr "src", path

# images
method to_html*(blk: FImagesBlock, context: FContext): El =
  let images = blk.images.map((path) => context.config.image_path(path, context))
  template render_td =
    el"td":
      if col.is_even:
        it.style "width: 1.33%;"
      else:
        it.style "width: 24%; text-align: center; vertical-align: middle;"
        if i < images.len:
          el".ftext_images_image_container":
            el("img", it.attr("src", images[i]))
        i.inc

  if images.len <= 4:
    el"table cellspacing=0 cellpadding=0": # removing cell borders
      el"tr":
        var i = 0
        for col in 0..(images.high * 2 - 2):
          render_td()
  else:
    el"table cellspacing=0 cellpadding=0":
      # setting margin after each row
      it.style "border-spacing: 0 0.6rem; margin: -0.6rem 0; border-collapse: separate;"
      var i = 0
      for row in 0..(images.len / 4).floor.int:
        el"tr":
          for col in 0..6:
            render_td()

# table
method to_html*(blk: FTableBlock, context: FContext): El =
  # If columns has only images or embeds, making it no more than 25%
  var single_image_cols: seq[bool]
  block:
    proc has_single_image(text: FInlineText): bool =
      text.len == 1 and text[0].kind == embed and text[0].embed_kind == "image"

    for i in 0..(blk.cols - 1):
      var has_at_least_one_image = false; var has_non_image_content = false
      for row in blk.rows: #.allit(it[i].has_single_image):
        if   row[i].has_single_image: has_at_least_one_image = true
        elif row[i].len > 0:          has_non_image_content  = true
      single_image_cols.add has_at_least_one_image and not has_non_image_content

  el"table": # table
    if blk.header.is_some: # header
      el"tr .border-b.border-gray-200":
        let hrow = blk.header.get
        for i, hcell in hrow:
          el"th .py-1":
            if i < hrow.high: it.class "pr-4"
            if single_image_cols[i]: # image header
              it.style "width: 25%; text-align: center; vertical-align: middle;"
            else: # non image header
              it.style "text-align: left; vertical-align: middle;"
            it.html hcell.to_html(context)

    for i, row in blk.rows: # rows
      el"tr":
        if i < blk.rows.high: it.class "border-b border-gray-200"
        for i, cell in row: # cols
          el"td .py-1":
            if i < row.high: it.class "pr-4"
            if single_image_cols[i]: # cell with image
              it.style "width: 25%; text-align: center; vertical-align: middle;"
              el".ftext_table_image_container":
                it.html cell.to_html(context)
            else: # non image cell
              it.style "vertical-align: middle;"
              it.html cell.to_html(context)


# to_html FDoc -------------------------------------------------------------------------------------
template inline_warns(warns: seq[string]) =
  let warnsv: seq[string] = warns
  unless warnsv.is_empty:
    el"fwarns.block.border-l-4.border-orange-800":
      for warn in warnsv:
        el".inline-block .text-orange-800 .ml-2":
          it.text warn

template inline_tags(tags: seq[string], context: FContext) =
  let tagsv: seq[string] = tags
  unless tagsv.is_empty:
    el"ftags.block.flex.-mr-2":
      for tag in tagsv:
        el"a .mr-2 .text-blue-800":
          it.text "#" & tag
          it.attr("href", (context.config.tag_path)(tag, context))

template block_layout(tname: string, warns, tags: seq[string], context: FContext, code) =
  el(".block.pblock.flex.flex-col.space-y-1 .ftext c"):
    it.tag = tname
    inline_warns(warns)
    code
    inline_tags(tags, context)

proc to_html*(doc: FDoc, space_id: string, config = FHtmlConfig.init): El =
  let context = (doc, space_id, config).FContext
  el"fdoc.flex.flex-col .space-y-2":
    block_layout("ftitle", doc.warns, @[], context): # Title and warns
      el".text-xl":
        it.text doc.title

    for section in doc.sections: # Sections
      unless section.title.is_empty:
        block_layout("fsection", section.warns, section.tags, context):
          it.add section.to_html(context)

      for blk in section.blocks: # Blocks
        # Not showing tags for Text and List blocks
        let tags: seq[string] = if blk of FTextBlock or blk of FListBlock: @[] else: blk.tags
        block_layout(fmt"f{blk.raw.kind}", blk.warns, tags, context):
          it.add blk.to_html(context)

    unless doc.tags.is_empty: # Tags
      block_layout("fdoc-tags", @[], doc.tags, context):
        discard

proc static_page_styles: SafeHtml =
  let styles_path = current_source_path().parent_dir.absolute_path & "/render/static_page_build.css"
  let css = fs.read styles_path
  # result.add "<style>"
  # result.add css.replace(re"[\s\n]+", " ").replace(re"/\*.+?\*/", "").trim # minifying into oneline
  # result.add "</style>"
  result.add """<link rel="stylesheet" href="/render/static_page_build.css">"""

proc to_html_page*(doc: FDoc, space_id: string, config = FHtmlConfig.init): string =
  let doc_html = doc.to_html(space_id, config).to_html
  let title    = doc.title.escape_html

  fmt"""
    <!DOCTYPE html>
    <html>
      <head>
        <title>{title}</title>
        {static_page_styles()}
        <meta charset="UTF-8">
      </head>
      <body class="bg-slate-50">
        <div class="mx-auto py-4 max-w-5xl bg-white">

    <!-- FDoc -->
    <doc>

        </div>
      </body>
    </html>
  """.dedent.trim.replace("<doc>", doc_html)
