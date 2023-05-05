import base, mono/core

const mockup_mode = is_main_module

template nomockup*(class: string): string =
  if mockup_mode: "" else: class

proc IconButton*(icon: string, size = "w-5 h-5", color = "bg-gray-500"): El =
  bh"button $icon_button .svg-icon":
    it.class size & " " & color
    it.style "-webkit-mask-image: url(/palette/icons/" & icon & ".svg);"

type LRLayout* = ref object of Component
  left*, right*: seq[El]

proc render*(self: LRLayout): El =
  bh"""$lr_layout .w-full .flex {nomockup".min-h-screen"}""":
    h"$lr_left .w-9/12": # .z-10
      it.add self.left
    h""".w-3/12 .relative {nomockup".right-panel-hidden-icon"} .border-gray-300 .border-l .bg-slate-50""":
      h".absolute .top-0 .right-0 .m-2":
        h(IconButton, (icon: "controls"))
      h"""$lr_right {nomockup".right-panel-content"}""":
        it.add self.right

type RSection* = ref object of Component
  content*: El
  title*:   string
  closed*:  bool

proc init*(_: type[RSection], title = "", closed = false): RSection =
  RSection(title: title, closed: closed, content: El.init)

proc render*(self: RSection): El =
  bh"$rsection .relative .m-2 .mb-3":
    if self.closed:
      assert not self.title.is_empty, "can't have empty title on closed rsection"
      h".text-gray-300":
        it.text self.title
      h".absolute .top-0 .right-0 .pt-1":
        h(IconButton, (icon: "left", size: "w-4 h-4", color: "bg-gray-300"))
    else:
      if not self.title.is_empty:
        h".text-gray-300":
          it.text self.title
      it.add self.content

proc RFavorites*(links: openarray[(string, string)], closed = false): El =
  bh(RSection, (title: "Favorites", closed: closed)):
    it.content = bh"":
      for (text, link) in links:
        h"a.block.text-blue-800":
          it.text text
          it.location link

proc RBacklinks*(links: openarray[(string, string)], closed = false): El =
  bh(RSection, (title: "Backlinks", closed: closed)):
    it.content = bh"":
      for (text, link) in links:
        h"a .block .text-sm .text-blue-800":
          it.text text
          it.location link

type CloudTag* = tuple[text, link: string, size: int]
proc RTags*(tags: openarray[CloudTag], closed = false): El =
  bh(RSection, (title: "Tags", closed: closed)):
    it.content = bh".-mr-1":
      for (text, link, size) in tags:
        let size_class = case size
          of 0: "text-sm"
          of 1: ""
          of 2: "text-xl"
          else: throw "unknown size"

        h"a .mr-1 .align-middle .text-center .leading-4 .text-blue-800":
          it.class size_class
          it.text text
          it.location "#"

proc Search*(text = ""): El =
  bh("input $rsearch .border .rounded .border-gray-300 .px-1 .w-full " &
    ".focus:outline-none .placeholder-gray-500 type=text"):
    it.attr("placeholder", "Search...")
    if not text.is_empty: it.text text

proc RSpaceInfo*(closed = false): El =
  bh(RSection, (title: "Space", closed: closed)):
    it.content = bh"a .text-blue-800":
      it.text "Finance"
      it.location "#"

proc render_mockup: seq[El] =
  let links = [
    "How to trade safely", "Stock Option Insurance", "Simulating Risk", "Math Modelling"
  ].map((text) => (text, "#"))

  let tags: seq[CloudTag] = {
    "Stock": 1, "Trading": 0, "Market": 2, "Dollar": 0, "Euro": 1,
    "Taxes": 1, "Currency": 0, "Profit": 0, "Loss": 2, "Option": 1,
    "Strategy": 0, "Backtesting": 0
  }.map((t) => (t[0], "#", t[1]))

  result.add:
    bh".palette_section":
      h(LRLayout, ()):
        it.left = bhs:
          h"":
            it.text "a"

        it.right = bhs:
          h(RSection, ()):
            it.content = bh(IconButton, (icon: "edit"))
          h(RSection, ()):
            it.content = bh(Search, ())
          h(RFavorites, (links: links))
          h(RTags, (tags: tags))
          h(RSpaceInfo, ())
          h(RBacklinks, (links: links))
          h(RSection, (title: "Other", closed: true))


when is_main_module:
  let html = """
    <!DOCTYPE html>
    <html>
      <head>
        <link rel="stylesheet" href="/palette/build/palette.css"/>
        <title>Palette</title>
      </head>
      <body>

    {html}

      </body>
    </html>
  """.dedent.trim.replace("{html}", render_mockup().to_html)
  let fname = "store/assets/palette/palette.html"
  fs.write fname, html
  p fmt"{fname} generated"
  say "done"