import base, mono/core

type Palette* = object
  mockup*: bool

proc init*(_: type[Palette], mockup = false): Palette =
  Palette(mockup: mockup)

template nomockup*(class: string): string =
  if pl.mockup: "" else: class

template icon_button*(icon: string, size = "w-5 h-5", color = "bg-gray-500") =
  h"button$icon_button.svg-icon":
    it.class size & " " & color
    it.style "-webkit-mask-image: url(/palette/icons/" & icon & ".svg);"

template lr_layout*(left, right) =
  h"""$lr_layout .w-full.flex {nomockup".min-h-screen"}""":
    h"$lr_left .w-9/12": # .z-10
      left
    h""".w-3/12.relative {nomockup".right-panel-hidden-icon"} .border-gray-300.border-l.bg-slate-50""": # z-0.
      h".absolute.top-0.right-0 .p-2":
        icon_button "controls"
      h"""$lr_right {nomockup".right-panel-content"}""":
        right

template rcontrols*(content) =
  h"$rcontrols.p-2":
    content

template rsearch*(txt: string) =
  h"input$rsearch .border.rounded.border-gray-300.px-1.w-full.focus:outline-none.placeholder-gray-500 type=text":
    it.attr("placeholder", "Search...")
    if not txt.is_empty:
      it.text txt

proc render_mockup: seq[HtmlElement] =
  let pl = Palette.init(mockup = false)

  result.add:
    bh".palette_section":
      lr_layout:
        h"":
          it.text "a"
      do:
        rcontrols:
          icon_button "edit"
        rcontrols:
          rsearch ""

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
