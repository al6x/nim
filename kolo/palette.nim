import base, mono/core

# Support ------------------------------------------------------------------------------------------
type Palette* = object
  mockup_mode*: bool

proc init*(_: type[Palette], mockup_mode = false): Palette =
  Palette(mockup_mode: mockup_mode)

var palette* {.threadvar.}: Palette

proc nomockup*(class: string): string =
  if palette.mockup_mode: "" else: class

# Common -------------------------------------------------------------------------------------------
proc IconButton*(icon: string, size = "w-5 h-5", color = "bg-gray-500"): El =
  let asset_root = if palette.mockup_mode: "" else: "/palette/"
  el"button .svg-icon":
    it.class size & " " & color
    it.style fmt"-webkit-mask-image: url({asset_root}icons/" & icon & ".svg);"

proc SymButton*(sym: char, size = "w-5 h-5", color = "gray-500"): El =
  el"button":
    it.class size & " " & color
    it.text sym.to_s

type LRLayout* = ref object of Component
  left*, right*: seq[El]

proc set_attrs*(self: LRLayout) =
  discard

proc render*(self: LRLayout): El =
  el""".w-full .flex {nomockup".min-h-screen"}""":
    el"$LRLeft .w-9/12": # .z-10
      it.add self.left
    el""".w-3/12 .relative {nomockup".right-panel-hidden-icon"} .border-gray-300 .border-l .bg-slate-50""":
      el".absolute .top-0 .right-0 .m-2":
        el(IconButton, (icon: "controls"))
      el"""$LRRight {nomockup".right-panel-content"}""":
        it.add self.right

# Right --------------------------------------------------------------------------------------------
proc RSection*(title = "", closed = false, content: seq[El]): El =
  el".relative .m-2 .mb-3":
    if closed:
      assert not title.is_empty, "can't have empty title on closed rsection"
      el".text-gray-300":
        it.text title
      el".absolute .top-0 .right-0 .pt-1":
        el(IconButton, (icon: "left", size: "w-4 h-4", color: "bg-gray-300"))
    else:
      if not title.is_empty:
        el".text-gray-300":
          it.text title
      it.add content

proc RFavorites*(links: openarray[(string, string)], closed = false): El =
  el(RSection, (title: "Favorites", closed: closed)):
    for (text, link) in links:
      el"a.block.text-blue-800":
        it.text text
        it.location link

proc RBacklinks*(links: openarray[(string, string)], closed = false): El =
  el(RSection, (title: "Backlinks", closed: closed)):
    for (text, link) in links:
      el"a .block .text-sm .text-blue-800":
        it.text text
        it.location link

type CloudTag* = tuple[text, link: string, size: int]
proc RTags*(tags: openarray[CloudTag], closed = false): El =
  el(RSection, (title: "Tags", closed: closed)):
    el".-mr-1":
      for (text, link, size) in tags:
        let size_class = case size
          of 0: "text-sm"
          of 1: ""
          of 2: "text-xl"
          else: throw "unknown size"

        el"a .mr-1 .align-middle .text-center .leading-4 .text-blue-800":
          it.class size_class
          it.text text
          it.location "#"

proc Search*(text = ""): El =
  el("input .border .rounded .border-gray-300 .px-1 .w-full " &
    ".focus:outline-none .placeholder-gray-500 type=text"):
    it.attr("placeholder", "Search...")
    if not text.is_empty: it.text text

proc RSpaceInfo*(closed = false): El =
  el(RSection, (title: "Space", closed: closed)):
    el"a .text-blue-800":
      it.text "Finance"
      it.location "#"

# Left ---------------------------------------------------------------------------------------------
type Note* = ref object of Component
  title*: string
  tags*:  seq[string]

proc set_attrs*(self: Note, title: string, tags: seq[string]) =
  self.title = title; self.tags = tags

proc render*(self: Note, content: seq[El]): El =
  el"":
    el".text-xl .p-1":
      # <div class="anchor absolute left-1">#</div>
      it.text self.title

    it.add content

    el".flex .-mr-2":
      for tag in self.tags:
        el"a .mr-2 .text-blue-800":
          it.text tag
          it.location "#"

proc NoteSection*(title = "", content: seq[El]): El =
  el"":
    el".pl-6 .text-xl .p-1": # Title
      it.text title
    it.add content

# <div class="anchor absolute left-1">#</div>

proc NoteTextBlock*(html: string): El =
  el" .p-2":
    el"":
      it.attr("html", html)

proc NoteListBlock*(html: string): El =
  el" .p-2":
    el"":
      it.attr("html", html)

# Other --------------------------------------------------------------------------------------------
proc MockupSection*(title: string, content: seq[El]): El =
  el"":
    el".text-2xl .ml-5":
      it.text title
    el".border .border-gray-300 .m-5 .mt-1":
      it.add content

proc render_mockup: seq[El] =
  let links = [
    "How to trade safely", "Stock Option Insurance", "Simulating Risk", "Math Modelling"
  ].map((text) => (text, "#"))

  let tags: seq[CloudTag] = {
    "Stock": 1, "Trading": 0, "Market": 2, "Dollar": 0, "Euro": 1,
    "Taxes": 1, "Currency": 0, "Profit": 0, "Loss": 2, "Option": 1,
    "Strategy": 0, "Backtesting": 0
  }.map((t) => (t[0], "#", t[1]))

  let note_tags = @["Forex", "Margin", "Fake"]

  let text_block1_html =
    """
      There are multiple reasons to avoid Forex. Every single of those reasons is big enough
      to stay away from such investment. Forex has all of them.
    """.dedent.trim

  let text_block2_html =
    """
      <ul>
        <li>
          <b>Negative trend</b>. Odds are against you. Stock market on average goes up, but
            the currencies on average going down.
        </li>
        <li>
          <b>Leverage</b>. Insane leverage. The minimal transaction on Forex is one lot equal to
          100k$. If you don't have such <a class="text-link" href="#">money</a> - you will be using
          leverage, sometimes very huge leverage. Small market fluctuation - and the margin call would
          wipe you out.
        </li>
        <li>
          <b>No intrinsic value</b>. Unlike <a class="text-tag" href="#">#stocks</a> that has
          intrinsic value, currencies doesn't have it. Currencies are based on belief in those
          who controls it. And believes and actions of those who controls it can change suddently
          and because it doesn't has any bottom value, it can fell all the way down to zero.
        </li>
      <ul>
    """.dedent.trim

  let list_block1_html =
    """
      <div class="text-list-item">
        1.1 No right for a mistake. If you made a mistake on the stock market, if you can
        wait, there's a chance that over time stock will grow back. Not true for Forex.
      </div>

      <div class="text-list-item">
        1.2 Currency is a depreciating asset, it looses the value over time. The time plays against you.
      </div>

      <div class="text-list-item">
        1.3 Fees. With stock you can buy and hold over long period, paying little transaction fees.
        With Forex keeping currencies doesn't make sense because it's a depreciating asset, so
        there will be probably lots of transactions and lots of fees.
      </div>

      <div class="text-list-item">
        1.4 No discount on CGT - Capital Gain Tax. If you hold asset more than 1 year many countries
        give CGT discount. Because currencies depreciate over time and it doesn't make sense to hold
        it for long - such discount probably won't be utilised.
      </div>

      <div class="text-list-item">
        2.2 Impossible to make diversification. Because lots are so big - you need millions to create
        diversified portfolio on Forex. Although, it doesn't make sense to keep Forex portfolio anyway,
        because currencies loose value over time.
      </div>
    """.dedent.trim


  palette = Palette.init(mockup_mode = true)
  result.add:
    el(MockupSection, (title: "Note")):
      el(LRLayout, ()):

        it.left = els:
          el(Note, (title: "Avoid Forex", tags: note_tags)):
            el(NoteSection, ()):
              el(NoteTextBlock, (html: text_block1_html))
            el(NoteSection, ()):
              el(NoteTextBlock, (html: text_block2_html))
            el(NoteSection, (title: "Additional consequences of those 3 main issues")):
              el(NoteListBlock, (html: list_block1_html))

        it.right = els:
          el(RSection, ()):
            el(IconButton, (icon: "edit"))
          el(RSection, ()):
            el(Search, ())
          el(RFavorites, (links: links))
          el(RTags, (tags: tags))
          el(RSpaceInfo, ())
          el(RBacklinks, (links: links))
          el(RSection, (title: "Other", closed: true))


when is_main_module:
  let html = """
    <!DOCTYPE html>
    <html>
      <head>
        <link rel="stylesheet" href="build/palette.css"/>
        <title>Palette</title>
      </head>
      <body>

    {html}

      </body>
    </html>
  """.dedent.trim.replace("{html}", render_mockup().to_html(comments = true))
  let fname = "kolo/assets/palette/palette.html"
  fs.write fname, html
  p fmt"{fname} generated"
  say "done"