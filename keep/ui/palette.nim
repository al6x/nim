import base, mono/core, std/os, ftext/[core, parse, render]
import std/macros

# Support ------------------------------------------------------------------------------------------
type Palette* = ref object
  mockup_mode*: bool

proc init*(_: type[Palette], mockup_mode = false): Palette =
  Palette(mockup_mode: mockup_mode)

var palette* {.threadvar.}: Palette

proc nomockup*(class: string): string =
  if palette.mockup_mode: "" else: class

# Elementary ---------------------------------------------------------------------------------------
proc PIconButton*(icon: string, title = "", size = "w-5 h-5", color = "bg-gray-500"): El =
  let asset_root = if palette.mockup_mode: "" else: "/assets/palette/"
  el"button .block.svg-icon":
    it.class size & " " & color
    unless title.is_empty: it.attr("title", title)
    it.style fmt"-webkit-mask-image: url({asset_root}icons/" & icon & ".svg);"

proc PSymButton*(sym: char, size = "w-5 h-5", color = "gray-500"): El =
  el"button.block":
    it.class size & " " & color
    it.text sym.to_s

proc PTextButton*(text: string, color = "text-blue-800"): El =
  el"button":
    it.class color
    it.text text

type PMessageKind* = enum info, warn
proc PMessage*(text: string, kind: PMessageKind = info, top = false): El =
  el"pmessage .block.p-2.rounded.bg-slate-50":
    if top: it.class "m-5"
    case kind
    of info: discard
    of warn: it.class "text-orange-800"
    it.text text

# Right --------------------------------------------------------------------------------------------
proc PRBlock*(tname = "prblock", title = "", closed = false, content: seq[El]): El =
  el(tname & " .block.relative .m-2 .mb-3 flash c"):
    if closed:
      assert not title.is_empty, "can't have empty title on closed rsection"
      el".text-gray-300":
        it.text title
      el".absolute .top-0 .right-0 .pt-1":
        el(PIconButton, (icon: "left", size: "w-4 h-4", color: "bg-gray-300"))
    else:
      if not title.is_empty:
        el".text-gray-300":
          it.text title
      if content.is_empty:
        # Adding invisible button to keep height of control panel the same as with buttons
        alter_el(el(PIconButton, (icon: "edit"))):
          it.class("opacity-0")
      else:
        it.add content

proc PFavorites*(links: openarray[(string, string)], closed = false): El =
  el(PRBlock, (tname: "prblock-favorites", title: "Favorites", closed: closed)):
    for (text, link) in links:
      el"a.block.text-blue-800":
        it.text text
        it.attr("href", link)

proc PBacklinks*(links: openarray[(string, string)], closed = false): El =
  el(PRBlock, (tname: "prblock-backlinks", title: "Backlinks", closed: closed)):
    for (text, link) in links:
      el"a .block .text-sm .text-blue-800":
        it.text text
        it.attr("href", link)

type CloudTag* = tuple[text, link: string, size: int]
proc PTags*(tags: openarray[CloudTag], closed = false): El =
  el(PRBlock, (tname: "prblock-tags", title: "Tags", closed: closed)):
    el".-mr-1 flash":
      for (text, link, size) in tags:
        let size_class = case size
          of 0: "text-sm"
          of 1: ""
          of 2: "text-xl"
          else: throw "unknown size"

        el"a .mr-1 .align-middle .text-center .leading-4 .text-blue-800":
          it.class size_class
          it.text text
          it.attr("href", "#")

proc PSearchField*(text = ""): El =
  el("input .border .rounded .border-gray-300 .px-1 .w-full " &
    ".focus:outline-none .placeholder-gray-500 type=text"):
    it.attr("placeholder", "Search...")
    if not text.is_empty: it.value text

proc PSpaceInfo*(warns: openarray[(string, string)], closed = false): El =
  el(PRBlock, (tname: "prblock-space-info", title: "Space", closed: closed)):
    el"a .text-blue-800":
      it.text "Finance"
      it.attr("href", "#")

    if not warns.is_empty:
      el".border-l-2.border-orange-800 flex":
        for (text, link) in warns:
          el"a.block.ml-2 .text-sm .text-orange-800":
            it.text text
            it.attr("href", link)

# Blocks -------------------------------------------------------------------------------------------
template pblock_controls*(controls: seq[El], hover: bool) =
  unless controls.is_empty:
    el"pblock-controls .block.absolute.right-0.top-1.flex.bg-white .rounded.p-1":
      if hover and not palette.mockup_mode: it.class "hidden_controls"
      it.style "margin-top: 0;"
      for c in controls: it.add(c)

template pblock_warns*(warns: seq[string]) =
  let warnsv: seq[string] = warns
  unless warnsv.is_empty:
    el"pblock-warns .block.border-l-4.border-orange-800 flash":
      for warn in warnsv:
        el".inline-block .text-orange-800 .ml-2":
          it.text warn

template pblock_tags*(tags: seq[(string, string)]) =
  let tagsv: seq[(string, string)] = tags
  unless tagsv.is_empty:
    el"pblock-tags .block.flex.-mr-2 flash":
      for (tag, link) in tagsv:
        el"a .mr-2 .text-blue-800":
          it.text "#" & tag
          it.attr("href", link)

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

# FBlocks ------------------------------------------------------------------------------------------
proc with_path*(tags: seq[string], context: FContext): seq[(string, string)] =
  tags.map((tag) => (tag, (context.config.tag_path)(tag, context)))

proc PFSection*(section: FSection, context: FContext, controls: seq[El] = @[]): El =
  let html = render.to_html(section.to_html(context))
  pblock_layout("pblock-fsection", section.warns, controls, section.tags.with_path(context), true):
    el".ftext flash":
      it.html html

proc PFBlock*(blk: FBlock, context: FContext, controls: seq[El] = @[]): El =
  let html = render.to_html(blk.to_html(context))
  let tname = fmt"pblock-f{blk.raw.kind}"
  let tags: seq[(string, string)] =
    if blk of FTextBlock or blk of FListBlock: @[] else: blk.tags.with_path(context)
  pblock_layout(tname, blk.warns, controls, tags, true):
    el".ftext flash":
      it.html html

# Search -------------------------------------------------------------------------------------------
proc PSearchItem*(title, subtitle, before, match, after: string): El =
  pblock_layout("psearch-item"):
  # el".pl-8.pr-8 .mb-2":
    el"psearch-item .text-gray-500":
      el"span":
        it.text before
      el"span .font-bold.text-black":
        it.text match
      el"span":
        it.text after
      # el"span .mr-2"
      el"a .text-blue-800":
        it.text title
        it.attr("href", "#")
      if not subtitle.is_empty:
        el"span":
          it.text "/"
        el"a .text-blue-800":
          it.text title
          it.attr("href", "#")

# PApp ---------------------------------------------------------------------------------------------
proc papp_layout*(left, right: seq[El]): El =
  el("papp .block.w-full .flex " & nomockup".min-h-screen" & " c"):
    el"papp-left .block.w-9/12 c":
      it.add left
    el(".w-3/12 .relative " & nomockup".right-panel-hidden-icon" & " .border-gray-300 .border-l .bg-slate-50"):
      # el".absolute .top-0 .right-0 .m-2 .mt-4":
      #   el(PIconButton, (icon: "controls"))
      el("papp-right .block " & nomockup".right-panel-content" & " .pt-2 c"):
        it.add right

proc PApp*(
  title: string, title_hint = "", title_controls = seq[El].init,
  warns = seq[string].init,
  tags: seq[(string, string)] = @[], tags_controls = seq[El].init, tags_warns = seq[string].init,
  right: seq[El] = @[],
  content: seq[El]
): El =
  let left =
    el"pdoc .block.flex.flex-col .space-y-1.mt-2.mb-2 c":
      # el"a.block.absolute.left-2 .text-gray-300": # Anchor
      #   it.class "top-3.5"
      #   it.text "#"
      #   it.location "#"
      pblock_layout("pblock-doc-title", warns, title_controls, @[], false): # Title
        el".text-xl flash":
          it.text title
          it.attr("title", title_hint)

      it.add content

      unless tags.is_empty:
        pblock_layout("pblock-doc-tags", tags_warns, tags_controls, tags, true): # Tags
          discard

  papp_layout(@[left], right)

# Other --------------------------------------------------------------------------------------------
proc MockupSection*(title: string, content: seq[El]): El =
  el"pmockup .block c":
    el".relative.ml-5 .text-2xl":
      it.text title
    # el".absolute.right-5.top-3":
    #   el(PIconButton, (icon: "code"))
    el".border .border-gray-300 .rounded .m-5 .mt-1":
      it.add content

template mockup_section(title_arg: string, code) =
  let built: El = block: code
  result.add:
    el(MockupSection, (title: title_arg)):
      add_or_return_el built

type StubData = object
  links:     seq[(string, string)]
  tags:      seq[CloudTag]
  fdoc:      FDoc

var data: StubData
proc stub_data: StubData

proc render_mockup: seq[El] =
  data = stub_data()
  let fdoc = data.fdoc
  palette = Palette.init(mockup_mode = true)

  let controls_stub = @[
    el(PIconButton, (icon: "edit")),
    el(PIconButton, (icon: "controls"))
  ]

  let context: FContext = (fdoc, "sample", FHtmlConfig.init)

  mockup_section("Note"):
    let right = els:
      el(PRBlock, ()):
        el(PIconButton, (icon: "edit"))
      el(PRBlock, ()):
        el(PSearchField, ())
      el(PFavorites, (links: data.links))
      el(PTags, (tags: data.tags))
      el(PSpaceInfo, (warns: @[("12 warns", "/warns")]))
      el(PBacklinks, (links: data.links))
      el(PRBlock, (title: "Other", closed: true))

    el(PApp, (
      title: fdoc.title, title_controls: controls_stub,
      warns: fdoc.warns,
      tags: fdoc.tags.with_path(context), tags_controls: controls_stub,
      right: right
    )):
      for section in fdoc.sections: # Sections
        unless section.title.is_empty:
          el(PFSection, (section: section, context: context, controls: controls_stub))

        for blk in section.blocks: # Blocks
          el(PFBlock, (blk: blk, context: context, controls: controls_stub))

  mockup_section("Search"):
    let right = els:
      el(PRBlock, ()): # Adding empty controls, to keep search field same distance from the top
        el(PRBlock, ()):
          el(PSearchField, (text: "finance/ About Forex"))

    let search_controls = @[el(PIconButton, (icon: "cross"))]

    el(PApp, (title: "Found", title_controls: search_controls, right: right)):
      for i in 1..6:
        el(PSearchItem, (
          title: "Risk Simulation",
          subtitle: "",
          before: "there are multiple reasons to",
          match: "About Forex",
          after: "Every single of those reasons is big enough to stay away from " &
            "such investment. Forex has all of them"
        ))

      let more = 23
      if more > 0:
        pblock_layout("pblock-pagination"):
          el"":
            alter_el(el(PTextButton, (text: fmt"{more} more"))):
              it.class "block float-right"

  mockup_section("Misc"):
    el(PApp, (title: "Misc")):
      pblock_layout("pblock-misc"):
        el(PMessage, (text: "Some message"))

  mockup_section("Misc"):
    el(PMessage, (text: "Some top level message", top: true))

when is_main_module:
  let html = """
    <!DOCTYPE html>
    <html>
      <head>
        <title>Palette</title>
        <link rel="stylesheet" href="build/palette.css"/>
      </head>
      <body>

    {html}

      </body>
    </html>
  """.dedent.trim.replace("{html}", render_mockup().to_html)
  let dir = current_source_path().parent_dir.absolute_path
  let fname = fmt"{dir}/assets/palette/palette.html"
  fs.write fname, html
  p fmt"{fname} generated"
  # say "done"

proc stub_data: StubData =
  result.links = [
    "How to trade safely", "Stock Option Insurance", "Simulating Risk", "Math Modelling"
  ].map((text) => (text, "#"))

  result.tags = {
    "Stock": 1, "Trading": 0, "Market": 2, "Dollar": 0, "Euro": 1,
    "Taxes": 1, "Currency": 0, "Profit": 0, "Loss": 2, "Option": 1,
    "Strategy": 0, "Backtesting": 0
  }.map((t) => (t[0], "#", t[1]))

  let ui_dir = current_source_path().parent_dir.absolute_path
  result.fdoc = FDoc.read(fmt"{ui_dir}/assets/sample/about-forex.ft")