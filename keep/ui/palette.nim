import base, mono/core, std/os, ftext/parse, ../render/blocks, ../model/docm
# import std/macros

# Support ------------------------------------------------------------------------------------------
type Palette* = ref object
  mockup_mode*: bool

proc init*(_: type[Palette], mockup_mode = false): Palette =
  Palette(mockup_mode: mockup_mode)

var palette* {.threadvar.}: Palette

proc nomockup*(class: string): string =
  if palette.mockup_mode: "" else: class

proc keep_dir*(): string =
  current_source_path().parent_dir.parent_dir.absolute_path

# Elementary ---------------------------------------------------------------------------------------
proc PIconLink*(icon: string, title = "", size = "w-5 h-5", color = "bg-blue-800", url = "#"): El =
  let asset_root = if palette.mockup_mode: "" else: "/assets/palette/"
  el("a .block.svg-icon", (class: size & " " & color, href: url)):
    unless title.is_empty: it.attr("title", title)
    it.style fmt"-webkit-mask-image: url({asset_root}icons/" & icon & ".svg);"

proc PIconButton*(icon: string, title = "", size = "w-5 h-5", color = "bg-gray-500"): El =
  let asset_root = if palette.mockup_mode: "" else: "/assets/palette/"
  el("button .block.svg-icon", (class: size & " " & color)):
    unless title.is_empty: it.attr("title", title)
    it.style fmt"-webkit-mask-image: url({asset_root}icons/" & icon & ".svg);"

proc PSymButton*(sym: char, size = "w-5 h-5", color = "gray-500"): El =
  el("button.block", (class: size & " " & color, text: sym.to_s))

proc PTextButton*(text: string, color = "text-blue-800"): El =
  el("button", (class: color, text: text))

proc PTextLink*(text: string, color = "text-blue-800", url = "#"): El =
  el("a", (class: color, text: text, href: url))

type PMessageKind* = enum info, warn
proc PMessage*(text: string, kind: PMessageKind = info, top = false): El =
  el("pmessage .block.p-2.rounded.bg-slate-50", (text: text)):
    if top: it.class "m-5"
    case kind
    of info: discard
    of warn: it.class "text-orange-800"

proc PLink*(text: string, link: string): El =
  el("a.text-blue-800", (text: text, href: link))

# Right --------------------------------------------------------------------------------------------
proc PRBlock*(tname = "prblock", title = "", closed = false, content: seq[El] = @[]): El =
  el(tname & " .block.relative c"):
    if closed:
      assert not title.is_empty, "can't have empty title on closed rsection"
      el(".text-gray-300", (text: title))
      el".absolute .top-0 .right-0 .pt-1":
        el(PIconButton, (icon: "left", size: "w-4 h-4", color: "bg-gray-300"))
    else:
      if not title.is_empty:
        el(".text-gray-300", (text: title))
      if content.is_empty:
        # Adding invisible button to keep height of control panel the same as with buttons
        alter_el(el(PIconButton, (icon: "edit"))):
          it.class("opacity-0")
      else:
        it.add content

proc PFavorites*(links: openarray[(string, string)], closed = false): El =
  el(PRBlock, (tname: "prblock-favorites", title: "Favorites", closed: closed)):
    for (text, link) in links:
      el("a.block.text-blue-800", (text: text, href: link))

proc PBacklinks*(links: openarray[(string, string)], closed = false): El =
  el(PRBlock, (tname: "prblock-backlinks", title: "Backlinks", closed: closed)):
    for (text, link) in links:
      el("a .block .text-sm .text-blue-800", (text: text, href: link))

proc PTags*(closed = false, content: seq[El]): El =
  el(PRBlock, (tname: "prblock-tags", title: "Tags", closed: closed)):
    el".-mr-1":
      it.add content

type PTagStyle* = enum normal, included, excluded, ignored
proc PTag*(text: string, style: PTagStyle = normal): El =
  let class = case style
  of normal:   ".text-blue-800.bg-blue-50.border-blue-50"
  of included: ".text-blue-800.bg-blue-50.border-blue-50"
  of excluded: ".text-pink-800.bg-pink-50.border-pink-50"
  of ignored:  ".text-gray-400.border-gray-200"
  el("a.mr-1 .rounded.px-1.border", (text: text[0].to_s.to_upper & text[1..^1], class: class))

proc PSearchField*(): El =
  el("textarea .border .rounded .border-gray-300 .placeholder-gray-400 .px-1 .w-full " &
    ".focus:outline-none .placeholder-gray-500 .resize-none rows=2", (placeholder: "Find..."))

proc PSpaceInfo*(warns: openarray[(string, string)], closed = false): El =
  el(PRBlock, (tname: "prblock-space-info", title: "Space", closed: closed)):
    el("a .text-blue-800", (text: "Finance", href: "#"))

    if not warns.is_empty:
      el".border-l-2.border-orange-800 flex":
        for (text, link) in warns:
          el("a.block.ml-2 .text-sm .text-orange-800", (text: text, href: link))

proc PWarnings*(warns: openarray[(string, string)], closed = false): El =
  el".border-l-2.border-orange-800 flex":
    let class = ".block.ml-2 .text-sm .text-orange-800"
    for (text, link) in warns:
      if link.is_empty: el(class,         (text: text))
      else:             el(fmt"a{class}", (text: text, href: link))

# Components ---------------------------------------------------------------------------------------
proc PTable*(header = Option[seq[El]](), rows: seq[seq[El]]): El =
  el"table": # table
    el"tbody":
      if header.is_some: # header
        el"tr .border-b.border-gray-200":
          let hrow = header.get
          for i, hcell in hrow:
            el"th .py-1":
              if i < hrow.high: it.class "pr-4"
              # if single_image_cols[i]: # image header
              #   it.style "width: 25%; text-align: center; vertical-align: middle;"
              # else: # non image header
              it.style "text-align: left; vertical-align: middle;"
              # it.text hcell
              it.add hcell

      for i, row in rows: # rows
        el"tr":
          if i < rows.high: it.class "border-b border-gray-200"
          for i, cell in row: # cols
            el"td .py-1":
              if i < row.high: it.class "pr-4"
              # if single_image_cols[i]: # cell with image
              #   it.style "width: 25%; text-align: center; vertical-align: middle;"
              #   el".image_container.overflow-hidden .rounded":
              #     it.html cell.render_text(context)
              # else: # non image cell
              it.style "vertical-align: middle;"
              it.add cell

# Blocks -------------------------------------------------------------------------------------------
template pblock_controls*(controls: seq[El], hover: bool) =
  unless controls.is_empty:
    el("pblock-controls .block.absolute.right-0.top-1.flex.bg-white .rounded.p-1", (style: "margin-top: 0;")):
      if hover and not palette.mockup_mode: it.class "hidden_controls"
      for c in controls: it.add(c)

template pblock_warns*(warns: seq[string]) =
  let warnsv: seq[string] = warns
  unless warnsv.is_empty:
    el"pblock-warns .block.border-l-4.border-orange-800":
      for warn in warnsv:
        el(".inline-block .text-orange-800 .ml-2", (text: warn))

template pblock_tags*(tags: seq[(string, string)]) =
  let tagsv: seq[(string, string)] = tags
  unless tagsv.is_empty:
    el"pblock-tags .block.-mr-1":
      for (tag, link) in tagsv:
        el("a.mr-1 .rounded.px-1.border .text-blue-800.bg-blue-50.border-blue-50"):
          it.attr("href", link)
          it.text(tag) # .to_lower

template pblock_layout*(tname: string, code: untyped): auto =
  el(tname & " .pblock.flex.flex-col.space-y-1 c"):
    code

template pblock_layout*(
  tname: string, warns_arg: untyped, controls: seq[El], tags: seq[(string, string)], hover: bool, code
): auto =
  let warns: seq[string] = warns_arg # otherwise it clashes with template overriding
  pblock_layout(tname):
    if hover: it.class "pblock_hover"
    pblock_warns(warns)
    code
    pblock_tags(tags)
    # Should be the last one, otherwise the first element will have extra margin
    pblock_controls(controls, hover)

# PBlocks ------------------------------------------------------------------------------------------
proc with_path*(tags: seq[string], context: RenderContext): seq[(string, string)] =
  tags.map((tag) => (tag, (context.config.tag_path)(tag, context)))

# proc PSectionBlock*(section: SectionBlock, context: RenderContext, controls: seq[El] = @[]): El =
#   let html = render.to_html(section.to_html(context))
#   pblock_layout("pblock-fsection", section.warns, controls, section.tags.with_path(context), true):
#     el".ftext flash":
#       it.html html

proc PBlock*(blk: Block, context: RenderContext, controls: seq[El] = @[], hover = true): El =
  let html = render_block(blk, context).to_html
  let tname = fmt"pblock-f{blk.source.kind}"
  let tags = if blk.show_tags: blk.tags.with_path(context) else: @[]
  pblock_layout(tname, blk.warns, controls, tags, hover):
    el(".ftext", (html: html))

proc PPagination*(count, page, per_page: int, url: proc(n: int): string): El =
  if count <= per_page: return list_el()
  pblock_layout("pblock-pagination"):
    el"":
      let pages = (count/per_page).floor.int
      if page <= pages:
        let more = count - page * per_page
        alter_el(el(PTextLink, (text: fmt"Next {more} →", url: url(page + 1))), it.class "block float-right")

      let back_class = if page > 1: "block" else: "block hidden"
      alter_el(el(PTextLink, (text: fmt"← Back", url: url(page - 1))), it.class back_class)


# Search -------------------------------------------------------------------------------------------
type PFoundItem* = tuple[before, match, after: string]
proc PFoundBlock*(title: string, matches: seq[PFoundItem], url = "#"): El =
  assert not matches.is_empty, "at least one match expected"
  let controls = @[el(PIconLink, (icon: "link", url: url))]
  pblock_layout("pfound-block", seq[string].init, controls, seq[(string, string)].init, false):
    el"found-items.block":
      el("a.text-blue-800", (text: title, href: url))
      for i, (before, match, after) in matches:
        el"found-item.ml-4":
          it.html before.escape_html & build_el("span .bg-yellow-100", (text: match)).to_html & after.escape_html

proc PSearchInfo*(message: string): El =
  el(PRBlock, (tname: "prblock-filter-info")):
    el".text-sm.text-gray-400":
      it.text message

# PApp ---------------------------------------------------------------------------------------------
proc papp_layout*(left, right, right_down: seq[El]): El =
  el("papp .block.w-full .flex " & nomockup".min-h-screen" & " c"):
    el"papp-left .block.w-9/12 c":
      it.add left
    let class = nomockup"fixed right-0 top-0 bottom-0 overflow-y-scroll"
    # nomockup".right-panel-hidden-icon"
    el("papp-right .w-3/12.flex.flex-col.justify-between .border-gray-300.border-l.bg-slate-50", (class: class)):
      # el".absolute .top-0 .right-0 .m-2 .mt-4":
      #   el(PIconButton, (icon: "controls"))
      # el("papp-right .flex.flex-col.space-y-2.m-2 " & nomockup".right-panel-content" & " c"):
      # el("papp-right .flex.flex-col" & nomockup".right-panel-content" & " c"):
      el("papp-right-up .flex.flex-col.space-y-2.m-2 c"):
        it.add right
      el("papp-right-down .flex.flex-col.space-y-2.m-2 c"):
        it.add right_down

proc PApp*(
  title: string, title_hint = "", title_controls = seq[El].init,
  warns = seq[string].init,
  tags: seq[(string, string)] = @[], tags_controls = seq[El].init, tags_warns = seq[string].init,
  right: seq[El] = @[], right_down: seq[El] = @[],
  show_block_separator = false,
  content: seq[El]
): El =
  let left =
    el"pdoc .flex.flex-col .space-y-1.mt-2.mb-2 c":
      if show_block_separator: it.class "show_block_separator"
      # el"a.block.absolute.left-2 .text-gray-300": # Anchor
      #   it.class "top-3.5"
      #   it.text "#"
      #   it.location "#"
      unless title.is_empty:
        pblock_layout("pblock-doc-title", warns, title_controls, @[], false): # Title
          el(".text-2xl", (text: title, title: title_hint))

      it.add content

      unless tags.is_empty:
        pblock_layout("pblock-doc-tags", tags_warns, tags_controls, tags, true): # Tags
          discard

  papp_layout(@[left], right, right_down)

# Other --------------------------------------------------------------------------------------------
proc MockupSection*(title: string, content: seq[El]): El =
  el"pmockup .block c":
    el(".relative.ml-5 .text-2xl", (text: title))
    # el".absolute.right-5.top-3":
    #   el(PIconButton, (icon: "code"))
    el".border .border-gray-300 .rounded .m-5 .mt-1":
      it.add content

template mockup_section(title_arg: string, code) =
  let built: El = block: code
  result.add:
    el(MockupSection, (title: title_arg)):
      add_or_return_el built

type CloudTag* = tuple[text, link: string, size: int]
type StubData = object
  links:      seq[(string, string)]
  tags:       seq[string]
  tags_cloud: seq[CloudTag]
  doc:        Doc

var data: StubData
proc stub_data: StubData

proc render_mockup: seq[El] =
  data = stub_data()
  let doc = data.doc
  palette = Palette.init(mockup_mode = true)

  let controls_stub = @[
    el(PIconButton, (icon: "edit")),
    el(PIconButton, (icon: "controls"))
  ]

  let context: RenderContext = (doc, "sample", RenderConfig.init)

  mockup_section("Search"):
    let tags_el = block:
      let incl = @["Trading", "Profit"]; let excl = @["Euro"]
      el(PTags, ()):
        for tag in data.tags:
          let style =
            if   tag in incl: included
            elif tag in excl: excluded
            else:             ignored
          el(PTag, (text: tag, style: style))

    let right = els:
      alter_el(el(PSearchField, ())):
        it.text "finance/ About Forex"
      el(PSearchInfo, (message: "Found 300 blocks in 20ms"))
      it.add tags_el

    let search_controls = @[el(PIconButton, (icon: "cross"))]

    let matches: seq[PFoundItem] = @[(
      before: "there are multiple reasons about ",
      match: "Forex",
      after: " every single of those reasons is big enough to stay away from " &
        "such investment. Forex has all of them"
    ), (
      before: "Insane leverage. The minimal transaction Super",
      match: "Forex",
      after: " is one lot equal to 100k$. If you"
    )]

    el(PApp, (title: "Found", title_controls: search_controls, show_block_separator: true, right: right)):
      for i in 1..6:
        el(PFoundBlock, (title: "About Forex", matches: matches))

      el(PPagination, (count: 200, page: 2, per_page: 30, url: (proc (page: int): string = page.to_s)))

  mockup_section("Note"):
    let right = els:
      # el(PRBlock, ()):
      #   el(PIconButton, (icon: "edit"))
      el(PSearchField, ())
      el(PFavorites, (links: data.links))
      el(PTags, ()):
        for tag in data.tags:
          el(PTag, (text: tag))
      el(PBacklinks, (links: data.links))
      el(PRBlock, (title: "Other", closed: true))

    let right_down = els:
      el(PRBlock, (tname: "prblock-warnings")):
        el(PWarnings, (warns: @[("12 warns", "/warns")]))

    el(PApp, (
      title: doc.title, title_controls: controls_stub,
      warns: doc.warns,
      tags: doc.tags.with_path(context), tags_controls: controls_stub,
      right: right, right_down: right_down
    )):
      for blk in doc.blocks:
        el(PBlock, (blk: blk, context: context, controls: controls_stub))

  mockup_section("Misc"):
    el(PApp, (title: "Misc")):
      pblock_layout("pblock-misc"):
        el(PMessage, (text: "Some message"))

  mockup_section("Misc"):
    el(PMessage, (text: "Some top level message", top: true))

proc html_page(title, content: string): string =
  """
    <!DOCTYPE html>
    <html>
      <head>
        <title>{title}</title>
        <link rel="stylesheet" href="build/palette.css"/>
        <meta charset="utf-8"/>
      </head>
      <body>

    {content}

      </body>
    </html>
  """.dedent.trim
    .replace("{title}", title)
    .replace("{content}", content)

when is_main_module:
  block: # Palette
    let fname = fmt"{keep_dir()}/ui/assets/palette/palette.html"
    let html = html_page("Palette", render_mockup().to_html)
    fs.write fname, html
    p fmt"{fname} generated"

  block: # Forest
    let doc = Doc.read(fmt"{keep_dir()}/ui/assets/sample/forest.ft")
    let context: RenderContext = (doc, "sample", RenderConfig.init)
    let app = el(PApp, (
      title: doc.title, warns: doc.warns, tags: doc.tags.with_path(context)
    )):
      for blk in doc.blocks:
        el(PBlock, (blk: blk, context: context))
    let fname = fmt"{keep_dir()}/ui/assets/palette/forest.html"
    fs.write fname, html_page("Forest, Palette", app.to_html)
    p fmt"{fname} generated"

proc stub_data: StubData =
  result.links = [
    "How to trade safely", "Stock Option Insurance", "Simulating Risk", "Math Modelling"
  ].map((text) => (text, "#"))

  result.tags_cloud = {
    "Stock": 1, "Trading": 0, "Market": 2, "Dollar": 0, "Euro": 1,
    "Taxes": 1, "Currency": 0, "Profit": 0, "Loss": 2, "Option": 1,
    "Strategy": 0, "Backtesting": 0
  }.map((t) => (t[0], "#", t[1]))

  result.tags = result.tags_cloud.mapit(it[0])

  result.doc = Doc.read(fmt"{keep_dir()}/ui/assets/sample/about-forex.ft")