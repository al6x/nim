import base, ext/[html, url], ../model

type
  RenderContext* = tuple[sid, mono_id: string, config: RenderConfig]

  RenderConfig* = ref object
    link_path*:  proc (link: RecordId, context: RenderContext): string
    render_tag*: proc (tag: string, context: RenderContext): SafeHtml

# config -------------------------------------------------------------------------------------------
proc link_path*(link: RecordId, context: RenderContext): string =
  "/" & (if link.sid == ".": context.sid else: link.sid) & "/" & link.rid

proc tag_path*(tag: string): string =
  fmt"/tags/{tag}"

proc render_tag*(tag: string, context: RenderContext): SafeHtml =
  let ntag = tag.to_lower
  fmt"""<a class="tag" href="{tag.tag_path.escape_html}">{ntag.escape_html(quotes = false)}</a>"""

proc init*(_: type[RenderConfig]): RenderConfig =
  RenderConfig(link_path: link_path, render_tag: render_tag)

proc init*(_: type[RenderContext], sid, mono_id: string): RenderContext =
  (sid, mono_id, RenderConfig.init)

# Helpers ------------------------------------------------------------------------------------------
proc asset_path*(path, rid: string, context: RenderContext): string =
  Url.init(@[context.sid, rid, path], { "mono_id": context.mono_id }).to_s

# render_embed -------------------------------------------------------------------------------------
method render_embed*(embed: Embed, blk: Block, context: RenderContext): SafeHtml {.base.} =
  "<code>" & embed.kind.escape_html(quotes = false) & "{" & embed.body.escape_html(quotes = false) & "}</code>"

method render_embed*(embed: ImageEmbed, blk: Block, context: RenderContext): SafeHtml =
  let path = asset_path(embed.path, blk.did, context)
  fmt"""<img src="{path.escape_html}"/>"""

method render_embed*(embed: CodeEmbed, blk: Block, context: RenderContext): SafeHtml =
  fmt"""<code>{embed.code.escape_html}</code>"""

# show_tags ----------------------------------------------------------------------------------------
method show_tags*(blk: Block): bool {.base.} = true
method show_tags*(blk: TextBlock): bool = false
method show_tags*(blk: TableBlock): bool = false

# render_block -------------------------------------------------------------------------------------
# base block
method render_block*(blk: Block, context: RenderContext): El {.base.} =
  el".border-l-4.border-orange-800 .text-orange-800":
    el(".text-orange-800 .ml-2", (text: fmt"render_block not defined for: {blk.kind}"))

# title
method render_block*(title: TitleBlock, context: RenderContext): El =
  el(".text-2xl", (text: title.title))

# section
method render_block*(section: SectionBlock, context: RenderContext): El =
  el(".text-2xl", (text: section.title))

# subsection
method render_block*(blk: SubsectionBlock, context: RenderContext): El =
  el(".text-xl", (text: blk.title))

# text items
proc render_text*(text: Text, blk: Block, context: RenderContext): SafeHtml =
  var html = ""; let config = context.config

  var em = false
  for i, item in text:
    if   not em and item.em == true:
      em = true; html.add "<b>"
    elif em and item.em != true:
      em = false; html.add "</b>"

    case item.kind
    of TextItemKind.text:
      html.add item.text.escape_html(quotes = false)
    of TextItemKind.link:
      let path = config.link_path(item.link, context)
      html.add fmt"""<a class="link" href="{path.escape_html}">{item.text.escape_html(quotes = false)}</a>"""
    of TextItemKind.glink:
      html.add fmt"""<a class="glink" href="{item.glink.escape_html}">{item.text.escape_html(quotes = false)}</a>"""
    of TextItemKind.tag:
      html.add config.render_tag(item.text, context)
    of TextItemKind.embed:
      html.add: render_embed(item.embed, blk, context)

  if em:
    html.add "</b>"
  html

# text
method render_block*(blk: TextBlock, context: RenderContext): El =
  list_el:
    for i, pr in blk.ftext:
      case pr.kind
      of ParagraphKind.text:
        el("p", (html: pr.text.render_text(blk, context)))
      of ParagraphKind.list:
        el "ul":
          for list_item in pr.list:
            el("li", (html: list_item.render_text(blk, context)))

# list
method render_block*(blk: ListBlock, context: RenderContext): El =
  if blk.ph:
    list_el:
      for list_item in blk.list:
        el("p", (html: list_item.render_text(blk, context)))
  else:
    el "ul":
      for list_item in blk.list:
        el("li", (html: list_item.render_text(blk, context)))

# code
method render_block*(blk: CodeBlock, context: RenderContext): El =
  el("pre", (text: blk.code.escape_html(quotes = false)))

# image
method render_block*(blk: ImageBlock, context: RenderContext): El =
  let path = asset_path(blk.image, blk.did, context)
  el("a.block", (href: path, target: "_blank")):
    el("img", (src: path))

# images
method render_block*(blk: ImagesBlock, context: RenderContext): El =
  let cols = blk.cols.get(4)
  let images = blk.images.map((path) => asset_path(path, blk.did, context))
  let image_width = (100 - cols).float / cols.float

  template render_td =
    el"td":
      if col.is_even:
        it.style "width: 1%;"
      else:
        it.style fmt"width: {image_width}%; text-align: center; vertical-align: middle;"
        if i < images.len:
          let path = images[i]
          el("a.image_container.overflow-hidden .rounded.border.border-gray-200", (href: path, target: "_blank")):
            el("img", (src: path))
        i.inc

  # if images.len <= cols:
  #   el"table cellspacing=0 cellpadding=0": # removing cell borders
  #     el"tr":
  #       var i = 0
  #       for col in 0..(cols * 2 - 2):
  #         render_td()
  # else:
  el"table cellspacing=0 cellpadding=0":
    # setting margin after each row
    it.style "border-spacing: 0 0.6rem; margin: -0.6rem 0; border-collapse: separate;"
    el"tbody":
      var i = 0
      for row in 0..((images.len / cols).ceil.int - 1):
        el"tr":
          for col in 0..(cols * 2 - 2):
            render_td()

# table
proc render_table_as_cards*(blk: TableBlock, single_image_cols: seq[bool], context: RenderContext): El =
  let options = blk.cards.get(CardsViewOptions())
  let (cols, img_aspect_ratio) = (options.cols.get(4), options.img_aspect_ratio.get(1.5))
  let rows = blk.rows
  let card_width = (100 - cols).float / cols.float

  template render_td =
    el"td":
      if col.is_even:
        it.style "width: 1%;"
      else:
        it.style fmt"width: {card_width}%; vertical-align: top;" # vertical-align: middle
        if i < rows.len:
          let row = rows[i]
          el".flex.flex-col.space-y-1.py-1.overflow-hidden .rounded.border.border-gray-200":
            for j, cell in row:
              if single_image_cols[j]:
                # el"": # Image had to be nested in div, otherwise it's not scaled properly
                #   el".image_container":
                #     it.html cell.render_text(context)

                # The aspect ratio style had to be set on both image and container
                let style = "aspect-ratio: " & img_aspect_ratio.to_s & ";"
                el(".card_fixed_height_image", (style: style)):
                  it.html cell.render_text(blk, context).replace("<img", "<img style=\"" & style & "\"")
              else:
                el".px-2.whitespace-nowrap":
                  if j == 0: it.class "font-bold"
                  it.html cell.render_text(blk, context)
        i.inc

  el"": # It has to be nested in div otherwise `table-layout: fixed` doesn't work
    el"table cellspacing=0 cellpadding=0":
      it.style:
        "border-spacing: 0 0.6rem; margin: -0.6rem 0; border-collapse: separate;" & # setting margin after each row
        "table-layout: fixed; width: 100%" # Preventing table cell to get wider with `white-space: nowrap`:
      el"tbody":
        var i = 0
        for row in 0..((rows.len / cols).ceil.int - 1):
          el"tr":
            for col in 0..(cols * 2 - 2):
              render_td()

proc render_table_as_table*(blk: TableBlock, single_image_cols: seq[bool], context: RenderContext): El =
  el"table": # table
    el"tbody":
      if blk.header.is_some: # header
        el"tr .border-b.border-gray-200":
          let hrow = blk.header.get
          for i, hcell in hrow:
            el("th .py-1", (html: hcell.render_text(blk, context))):
              if i < hrow.high: it.class "pr-4"
              if single_image_cols[i]: # image header
                it.style "width: 25%; text-align: center; vertical-align: middle;"
              else: # non image header
                it.style "text-align: left; vertical-align: middle;"

      for i, row in blk.rows: # rows
        el"tr":
          if i < blk.rows.high: it.class "border-b border-gray-200"
          for i, cell in row: # cols
            el"td .py-1":
              if i < row.high: it.class "pr-4"
              if single_image_cols[i]: # cell with image
                it.style "width: 25%; text-align: center; vertical-align: middle;"
                el".image_container.overflow-hidden .rounded":
                  it.html cell.render_text(blk, context)
              else: # non image cell
                it.style "vertical-align: middle;"
                it.html cell.render_text(blk, context)

method render_block*(blk: TableBlock, context: RenderContext): El =
  # If columns has only images or embeds, making it no more than 25%
  var single_image_cols: seq[bool]
  block:
    proc has_single_image(text: Text): bool =
      text.len == 1 and text[0].kind == embed and text[0].embed of ImageEmbed

    for i in 0..(blk.cols - 1):
      var has_at_least_one_image = false; var has_non_image_content = false
      for row in blk.rows: #.allit(it[i].has_single_image):
        if   row[i].has_single_image: has_at_least_one_image = true
        elif row[i].len > 0:          has_non_image_content  = true
      single_image_cols.add has_at_least_one_image and not has_non_image_content

  if blk.style == cards: render_table_as_cards(blk, single_image_cols, context)
  else:                  render_table_as_table(blk, single_image_cols, context)


# # to_html FDoc -------------------------------------------------------------------------------------
# template inline_warns(warns: seq[string]) =
#   let warnsv: seq[string] = warns
#   unless warnsv.is_empty:
#     el"fwarns.block.border-l-4.border-orange-800":
#       for warn in warnsv:
#         el".inline-block .text-orange-800 .ml-2":
#           it.text warn

# template inline_tags(tags: seq[string], context: RenderContext) =
#   let tagsv: seq[string] = tags
#   unless tagsv.is_empty:
#     el"ftags.block.flex.-mr-2":
#       for tag in tagsv:
#         el"a .mr-2 .text-blue-800":
#           it.text "#" & tag
#           it.attr("href", (context.config.tag_path)(tag, context))

# template block_layout(tname: string, warns, tags: seq[string], context: RenderContext, code) =
#   el(".block.pblock.flex.flex-col.space-y-1 .ftext c"):
#     it.tag = tname
#     inline_warns(warns)
#     code
#     inline_tags(tags, context)

# proc to_html*(doc: FDoc, sid: string, config = RenderConfig.init): El =
#   let context = (doc, sid, config).RenderContext
#   el"fdoc.flex.flex-col .space-y-2":
#     block_layout("ftitle", doc.warns, @[], context): # Title and warns
#       el".text-xl":
#         it.text doc.title

#     for section in doc.sections: # Sections
#       unless section.title.is_empty:
#         block_layout("fsection", section.warns, section.tags, context):
#           it.add section.to_html(context)

#       for blk in section.blocks: # Blocks
#         # Not showing tags for Text and List blocks
#         let tags: seq[string] = if blk of FTextBlock or blk of FListBlock: @[] else: blk.tags
#         block_layout(fmt"f{blk.raw.kind}", blk.warns, tags, context):
#           it.add blk.to_html(context)

#     unless doc.tags.is_empty: # Tags
#       block_layout("fdoc-tags", @[], doc.tags, context):
#         discard

# proc static_page_styles: SafeHtml =
#   let styles_path = current_source_path().parent_dir.absolute_path & "/render/static_page_build.css"
#   let css = fs.read styles_path
#   # result.add "<style>"
#   # result.add css.replace(re"[\s\n]+", " ").replace(re"/\*.+?\*/", "").trim # minifying into oneline
#   # result.add "</style>"
#   result.add """<link rel="stylesheet" href="/render/static_page_build.css">"""

# proc to_html_page*(doc: FDoc, sid: string, config = RenderConfig.init): string =
#   let doc_html = doc.to_html(sid, config).to_html
#   let title    = doc.title.escape_html

#   fmt"""
#     <!DOCTYPE html>
#     <html>
#       <head>
#         <title>{title}</title>
#         {static_page_styles()}
#         <meta charset="UTF-8">
#       </head>
#       <body class="bg-slate-50">
#         <div class="mx-auto py-4 max-w-5xl bg-white">

#     <!-- FDoc -->
#     <doc>

#         </div>
#       </body>
#     </html>
#   """.dedent.trim.replace("<doc>", doc_html)
