import base, mono/core

type Palette* = object
  mockup*: bool

proc init*(_: type[Palette], mockup = false): Palette =
  Palette(mockup: mockup)

template nomockup*(class: string): string =
  if pl.mockup: "" else: class

proc icon_button*(pl: Palette, icon: string, size = "w-5 h-5", color = "bg-gray-500"): HtmlElement =
  h"button.ICON_BUTTON_C.svg-icon".class(size & " " & color)
    .attr("style", fmt"-webkit-mask-image: url(/palette/icons/{icon}.svg);")

template lr_layout*(pl: Palette, left, right): HtmlElement =
  h".LR_LAYOUT_C.w-full.flex".class(nomockup"min-h-screen").content:
    + h".w-9/12": # .z-10
      left
    + h".w-3/12.relative .border-gray-300.border-l.bg-slate-50": # z-0.
      + h".absolute.top-0.right-0 .p-2".class(nomockup"right-panel-hidden-icon").content:
        + pl.icon_button("controls")
      + h"".class(nomockup"right-panel-content").content:
        right

template rcontrols*(pl: Palette, blk): HtmlElement =
  h".RCONTROLS_C.p-2":
    blk

proc render_mockup: seq[HtmlElement] =
  let pl = Palette.init(mockup = true)

  result.add h""
  result.add:
    pl.rcontrols:
      echo 1

  # result.add:
  #   pl.lr_layout:
  #     + h"".text("a")
  #   do:
  #     + pl.rcontrols:
  #       + pl.icon_button("edit")

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
