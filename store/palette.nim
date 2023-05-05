import base, mono/core

type Palette* = object
  mockup*: bool

proc init*(_: type[Palette], mockup = false): Palette =
  Palette(mockup: mockup)

template nomockup*(class: string): string =
  if pl.mockup: "" else: class

template icon_button*(icon: string, size = "w-5 h-5", color = "bg-gray-500") =
  h"button $icon_button .svg-icon":
    it.class size & " " & color
    it.style "-webkit-mask-image: url(/palette/icons/" & icon & ".svg);"

template lr_layout*(left, right) =
  h"""$lr_layout .w-full .flex {nomockup".min-h-screen"}""":
    h"$lr_left .w-9/12": # .z-10
      left
    h""".w-3/12 .relative {nomockup".right-panel-hidden-icon"} .border-gray-300 .border-l .bg-slate-50""":
      h".absolute .top-0 .right-0 .m-2":
        icon_button "controls"
      h"""$lr_right {nomockup".right-panel-content"}""":
        right

template rsection*(title: string, closed: bool, content) =
  h"$rsection .relative .m-2 .mb-3":
    if closed:
      assert not title.is_empty, "can't have empty title on closed rsection"
      h".text-gray-300":
        it.text title
      h".absolute .top-0 .right-0 .pt-1":
        icon_button("left", "w-4 h-4", "bg-gray-300")
    else:
      if not title.is_empty:
        h".text-gray-300":
          it.text title
      content

template rfavorites*(links: openarray[(string, string)], closed: bool) =
  rsection "Favorites", closed:
    it.c "rfavorites"
    h"":
      for (text, link) in links:
        h"a.block.text-blue-800":
          it.text text
          it.location link

template rbacklinks*(links: openarray[(string, string)], closed: bool) =
  rsection "Backlinks", closed:
    it.c "rbacklinks"
    h"":
      for (text, link) in links:
        h"a .block .text-sm .text-blue-800":
          it.text text
          it.location link

type CloudTag* = tuple[text, link: string, size: int]
template rtags*(tags: openarray[CloudTag], closed: bool) =
  rsection "Tags", closed:
    it.c "rtags"
    h".-mr-1":
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

template search*(txt: string) =
  h("input $rsearch .border .rounded .border-gray-300 .px-1 .w-full " &
    ".focus:outline-none .placeholder-gray-500 type=text"):
    it.attr("placeholder", "Search...")
    if not txt.is_empty:
      it.text txt

template rspace_info*(closed: bool) =
  rsection "Space", closed:
    it.c "rspace"
    h"a .text-blue-800":
      it.text "Finance"
      it.location "#"

proc render_mockup: seq[HtmlElement] =
  let pl = Palette.init(mockup = false)

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
      lr_layout:
        h"":
          it.text "a"
      do:
        rsection "", false:
          icon_button "edit"
        rsection "", false:
          search ""
        rfavorites links, false
        rtags tags, false
        rspace_info false
        rbacklinks links, false
        rsection "Other", true:
          discard

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
