import base, ext/html, ../model

type
  RenderContext* = tuple[doc: Doc, space_id: string, config: RenderConfig]

  RenderConfig* = ref object
    link_path*:  proc (link: Link, context: RenderContext): string
    tag_path*:   proc (tag: string, context: RenderContext): string
    asset_path*: proc (path: string, context: RenderContext): string

# config -------------------------------------------------------------------------------------------
proc link_path*(link: Link, context: RenderContext): string =
  ("/" & (if link.sid == ".": context.space_id else: link.sid)) &
  ("/" & link.did) &
  (if link.bid.is_empty: "" else: "/" & link.bid)

proc tag_path*(tag: string, context: RenderContext): string =
  fmt"/tags/{tag}"

proc asset_path*(path: string, context: RenderContext): string =
  "/" & context.space_id & "/" & context.doc.id & "/" & path

proc init*(_: type[RenderConfig]): RenderConfig =
  RenderConfig(link_path: link_path, tag_path: tag_path, asset_path: asset_path)

# render_embed -------------------------------------------------------------------------------------
method render_embed*(embed: Embed, context: RenderContext): SafeHtml {.base.} =
  "<code>" & embed.kind.escape_html & "{" & embed.body.escape_html & "}</code>"

method render_embed*(embed: ImageEmbed, context: RenderContext): SafeHtml =
  let path = context.config.asset_path(embed.path, context)
  fmt"""<img src="{path.escape_html}"/>"""

method render_embed*(embed: CodeEmbed, context: RenderContext): SafeHtml =
  fmt"""<code>{embed.code.escape_html}</code>"""


# render_block -------------------------------------------------------------------------------------
# base block
method render_block*(blk: Block, context: RenderContext): El {.base.} =
  el".border-l-4.border-orange-800 .text-orange-800":
    el".text-orange-800 .ml-2":
      it.text fmt"render_block not defined for {blk.source.kind}"

# section
method render_block*(section: SectionBlock, context: RenderContext): El =
  el".text-2xl":
    it.text section.title

# subsection
method render_block*(blk: SubsectionBlock, context: RenderContext): El =
  el".text-xl":
    it.text blk.title

# text items
proc render_text*(text: Text, context: RenderContext): SafeHtml =
  var html = ""; let config = context.config

  var em = false
  for i, item in text:
    if   not em and item.em == true:
      em = true; html.add "<b>"
    elif em and item.em != true:
      em = false; html.add "</b>"

    case item.kind
    of TextItemKind.text:
      html.add item.text.escape_html
    of TextItemKind.link:
      let path = config.link_path(item.link, context)
      html.add fmt"""<a class="link" href="{path.escape_html}">{item.text.escape_html}</a>"""
    of TextItemKind.glink:
      html.add fmt"""<a class="glink" href="{item.glink.escape_html}">{item.text.escape_html}</a>"""
    of TextItemKind.tag:
      let path = config.tag_path(item.text, context)
      html.add fmt"""<a class="tag" href="/tags/{item.text.escape_html}">#{item.text.escape_html}</a>"""
    of TextItemKind.embed:
      html.add: render_embed(item.embed, context)

  if em:
    html.add "</b>"
  html

# text
method render_block*(blk: TextBlock, context: RenderContext): El =
  list_el:
    for i, pr in blk.ftext:
      case pr.kind
      of ParagraphKind.text:
        el "p":
          it.html pr.text.render_text(context)
      of ParagraphKind.list:
        el "ul":
          for list_item in pr.list:
            el "li":
              it.html list_item.render_text(context)

# list
method render_block*(blk: ListBlock, context: RenderContext): El =
  if blk.ph:
    list_el:
      for list_item in blk.list:
        el "p":
          it.html list_item.render_text(context)
  else:
    el "ul":
      for list_item in blk.list:
        el "li":
          it.html list_item.render_text(context)

# code
method render_block*(blk: CodeBlock, context: RenderContext): El =
  el"pre":
    it.text blk.code.escape_html

# image
method render_block*(blk: ImageBlock, context: RenderContext): El =
  let path = context.config.asset_path(blk.image, context)
  el"a.block":
    it.attr("href", path)
    it.attr("target", "_blank")
    el("img", it.attr("src", path))

# images
method render_block*(blk: ImagesBlock, context: RenderContext): El =
  let cols = blk.cols.get(min(4, blk.images.len))
  let images = blk.images.map((path) => context.config.asset_path(path, context))
  let image_width = (100 - cols).float / cols.float

  template render_td =
    el"td":
      if col.is_even:
        it.style "width: 1%;"
      else:
        it.style fmt"width: {image_width}%; text-align: center; vertical-align: middle;"
        if i < images.len:
          let path = images[i]
          el"a.ftext_images_image_container":
            it.attr("target", "_blank")
            it.attr("href", path)
            el("img", it.attr("src", path))
        i.inc

  if images.len <= cols:
    el"table cellspacing=0 cellpadding=0": # removing cell borders
      el"tr":
        var i = 0
        for col in 0..(cols * 2 - 2):
          render_td()
  else:
    el"table cellspacing=0 cellpadding=0":
      # setting margin after each row
      it.style "border-spacing: 0 0.6rem; margin: -0.6rem 0; border-collapse: separate;"
      var i = 0
      for row in 0..(images.len / cols).floor.int:
        el"tr":
          for col in 0..(cols * 2 - 2):
            render_td()

# table
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
            it.html hcell.render_text(context)

    for i, row in blk.rows: # rows
      el"tr":
        if i < blk.rows.high: it.class "border-b border-gray-200"
        for i, cell in row: # cols
          el"td .py-1":
            if i < row.high: it.class "pr-4"
            if single_image_cols[i]: # cell with image
              it.style "width: 25%; text-align: center; vertical-align: middle;"
              el".ftext_table_image_container":
                it.html cell.render_text(context)
            else: # non image cell
              it.style "vertical-align: middle;"
              it.html cell.render_text(context)


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

# proc to_html*(doc: FDoc, space_id: string, config = RenderConfig.init): El =
#   let context = (doc, space_id, config).RenderContext
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

# proc to_html_page*(doc: FDoc, space_id: string, config = RenderConfig.init): string =
#   let doc_html = doc.to_html(space_id, config).to_html
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
