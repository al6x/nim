import base, mono/core, std/os

# Support ------------------------------------------------------------------------------------------
type Palette* = ref object
  mockup_mode*: bool

proc init*(_: type[Palette], mockup_mode = false): Palette =
  Palette(mockup_mode: mockup_mode)

var palette* {.threadvar.}: Palette

proc nomockup*(class: string): string =
  if palette.mockup_mode: "" else: class

# Common -------------------------------------------------------------------------------------------
proc IconButton*(icon: string, title = "", size = "w-5 h-5", color = "bg-gray-500"): El =
  let asset_root = if palette.mockup_mode: "" else: "/assets/palette/"
  el"button .block.svg-icon":
    it.class size & " " & color
    unless title.is_empty: it.attr("title", title)
    it.style fmt"-webkit-mask-image: url({asset_root}icons/" & icon & ".svg);"

proc SymButton*(sym: char, size = "w-5 h-5", color = "gray-500"): El =
  el"button.block":
    it.class size & " " & color
    it.text sym.to_s

proc TextButton*(text: string, color = "text-blue-800"): El =
  el"button":
    it.class color
    it.text text

type LRLayout* = ref object of Component
  left*, right*: seq[El]

proc set_attrs*(self: LRLayout) =
  discard

proc render*(self: LRLayout): El =
  el""".w-full .flex {nomockup".min-h-screen"}""":
    el"$LRLeft .w-9/12": # .z-10
      it.add self.left
    el"""$LRRight.w-3/12 .relative {nomockup".right-panel-hidden-icon"} .border-gray-300 .border-l .bg-slate-50""":
      el".absolute .top-0 .right-0 .m-2 .mt-4":
        el(IconButton, (icon: "controls"))
      el"""$LRRight {nomockup".right-panel-content"} .pt-2""":
        it.add self.right

type MessageKind* = enum info, warn
proc Message*(text: string, kind: MessageKind = info): El =
  el".m-2 .p-2.rounded.bg-slate-50":
    case kind
    of info: discard
    of warn: it.class "text-orange-800"
    it.text text

# Right --------------------------------------------------------------------------------------------
proc RSection*(title = "", closed = false, content: seq[El]): El =
  el".relative .m-2 .mb-3 flash":
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
      if content.is_empty:
        # Adding invisible button to keep height of control panel the same as with buttons
        el(IconButton, (icon: "edit")):
          it.class("opacity-0")
      else:
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
          it.location "#"

proc RSearchField*(text = ""): El =
  el("input .border .rounded .border-gray-300 .px-1 .w-full " &
    ".focus:outline-none .placeholder-gray-500 type=text"):
    it.attr("placeholder", "Search...")
    if not text.is_empty: it.value text

proc RSpaceInfo*(warns: openarray[(string, string)], closed = false): El =
  el(RSection, (title: "Space", closed: closed)):
    el"a .text-blue-800":
      it.text "Finance"
      it.location "#"

    if not warns.is_empty:
      el".border-l-2.border-orange-800 flex":
        for (text, link) in warns:
          el"a.block.ml-2 .text-sm .text-orange-800":
            it.text text
            it.location link

# Note ---------------------------------------------------------------------------------------------
template inline_controls(controls: seq[El]): auto =
  unless controls.is_empty:
    el"""{nomockup".hidden_controls"}.absolute.right-0.top-1.flex.bg-white .rounded.p-1""":
      it.style "margin-top: 0;"
      for c in controls: it.add(c)

template inline_warns(warns: seq[string]): auto =
  unless warns.is_empty:
    el".border-l-4.border-orange-800 flash":
      for w in warns:
        el".inline-block .text-orange-800 .ml-2":
          it.text w

template inline_tags(tags: seq[string]): auto =
  let tagsv: seq[string] = tags
  unless tagsv.is_empty:
    el".flex.-mr-2 flash":
      for tag in tagsv:
        el"a .mr-2 .text-blue-800":
          it.text "#" & tag
          it.location "#"

template note_block(controls: seq[El], warns: seq[string], tags: seq[string], code): auto =
  el".note_block.flex.flex-col.space-y-1":
    inline_warns(warns)
    code
    inline_tags(tags)
    # Should be the last one, otherwise the first element will have extra margin
    inline_controls(controls)

proc Note*(
  title: string, location = "", title_controls = seq[El].init,
  warns = seq[string].init,
  tags: seq[string], tags_controls = seq[El].init, tags_warnings = seq[string].init,
  content: seq[El]
): El =
  el".flex.flex-col .space-y-1.mt-2.mb-2":
    # el"a.block.absolute.left-2 .text-gray-300": # Anchor
    #   it.class "top-3.5"
    #   it.text "#"
    #   it.location "#"
    note_block(title_controls, warns, @[]): # Title
      el".text-xl flash":
        it.text title
        it.attr("title", location)

    it.add content

    note_block(tags_controls, tags_warnings, tags): # Tags
      discard

proc NoteSection*(
  title: string, tags: seq[string] = @[], controls: seq[El] = @[], warns: seq[string] = @[]
): El =
  el".note_block":
    el".text-xl flash": # Title
      it.text title
    inline_warns(warns)
    inline_tags(tags)
    # Should be the last one, otherwise the first element will have extra margin
    inline_controls(controls)

proc NoteTextBlock*(html: safe_html, controls = seq[El].init, warns: seq[string] = @[]): El =
  note_block(controls, warns, @[]):
    el".ftext flash": # Body
      it.attr("html", html)

proc NoteListBlock*(html: safe_html, controls = seq[El].init, warns: seq[string] = @[]): El =
  note_block(controls, warns, @[]):
    el".ftext flash": # Body
      it.attr("html", html.to_s)

proc NoteCodeBlock*(
  code: string, controls = seq[El].init, warns: seq[string] = @[], tags: seq[string] = @[]
): El =
  note_block(controls, warns, tags):
    el".ftext flash": # Body
      it.attr("html", "<pre>" & code.escape_html & "</pre>")

proc NoteImagesBlock*(
  images: seq[string], controls = seq[El].init, warns: seq[string] = @[], tags: seq[string] = @[]
): El =
  template render_td =
    el"td":
      if col.is_even:
        it.style "width: 1.33%;"
      else:
        it.style "width: 24%; text-align: center; vertical-align: middle;"
        if i < images.len:
          # flex needed to align vertically
          el".flex .rounded.overflow-hidden.border.border-gray-300.bg-slate-50":
            it.style "width: 100%; aspect-ratio: 1;" # making height same as width so cell will be square
            el"img.block.ml-auto.mr-auto": # centering horizontally
              # Limiting image max height and width
              it.style "object-fit: contain; max-width: 100%; max-height: 100%; width: auto; height: auto;"
              it.attr("src", images[i])
              i.inc

  note_block(controls, warns, tags):
    if images.len <= 4:
      el"table cellspacing=0 cellpadding=0 flash": # removing cell borders
        el"tdata":
          el"tr":
            var i = 0
            for col in 0..(images.high * 2 - 2):
              render_td()
    else:
      el"table cellspacing=0 cellpadding=0 flash":
        it.style "border-spacing: 0 0.6rem; border-collapse: separate;" # setting margin after each row
        el"tdata":
          var i = 0
          for row in 0..(images.len / 4).floor.int:
            el"tr":
              for col in 0..6:
                render_td()

# Search -------------------------------------------------------------------------------------------
proc SearchItem*(title, subtitle, before, match, after: string): El =
  el".pl-8.pr-8 .mb-2":
    el"span .text-gray-500":
      el"span":
        it.text before
      el"span .font-bold.text-black":
        it.text match
      el"span":
        it.text after
      # el"span .mr-2"
      el"a .text-blue-800":
        it.text title
        it.location "#"
      if not subtitle.is_empty:
        el"span":
          it.text "/"
        el"a .text-blue-800":
          it.text title
          it.location "#"

proc Search*(title = "Found", more: int, content: seq[El]): El =
  el".pt-3.pb-3":
    el".float-right.mr-8.mt-1":
      el(IconButton, (icon: "cross"))
    el".pl-8.mb-2 .text-xl":
      it.text title
    el"":
      it.add content

    if more > 0:
      el".pl-8.pr-8.mb-2.float-right":
        el(TextButton, (text: fmt"{more} more"))


# Other --------------------------------------------------------------------------------------------
proc MockupSection*(title: string, content: seq[El]): El =
  el"":
    el".relative.ml-5 .text-2xl":
      it.text title
    # el".absolute.right-5.top-3":
    #   el(IconButton, (icon: "code"))
    el".border .border-gray-300 .rounded .m-5 .mt-1":
      it.add content

template mockup_section(t: string, code) =
  result.add:
    el(MockupSection, (title: t)):
      code

type StubData = object
  links:     seq[(string, string)]
  tags:      seq[CloudTag]
  note_tags: seq[string]

  text_block1_html, text_block2_html, list_block1_html, text_block_with_image_html: safe_html
  code_block1: string
  knots: seq[string]

var data: StubData
proc stub_data: StubData

proc render_mockup: seq[El] =
  data = stub_data()
  palette = Palette.init(mockup_mode = true)

  let controls_stub = @[
    el(IconButton, (icon: "edit")),
    el(IconButton, (icon: "controls"))
  ]

  mockup_section("Note"):
    el(LRLayout, ()):

      it.left = els:
        el(Note, (title: "About Forex", title_controls: controls_stub, tags: data.note_tags,
          tags_controls: controls_stub)):
          # el(NoteSection, ())
          el(NoteTextBlock, (html: data.text_block1_html))
          el(NoteSection, (title: "Trends are down", tags: @["Finance", "Trading"]))
          el(NoteTextBlock, (html: data.text_block2_html, controls: controls_stub))
          el(NoteSection, (title: "Additional consequences of those 3 main issues", controls: controls_stub))
          el(NoteListBlock, (html: data.list_block1_html, warns: @["Invalid tag #some", "Invalid link /some"]))

      it.right = els:
        el(RSection, ()):
          el(IconButton, (icon: "edit"))
        el(RSection, ()):
          el(RSearchField, ())
        el(RFavorites, (links: data.links))
        el(RTags, (tags: data.tags))
        el(RSpaceInfo, (warns: @[("12 warns", "/warns")]))
        el(RBacklinks, (links: data.links))
        el(RSection, (title: "Other", closed: true))

  mockup_section("Text"):
    el(LRLayout, ()):
      it.left = els:
        el(Note, (title: "About Forex", tags: data.note_tags)):
          # el(NoteSection, ())
          el(NoteTextBlock, (html: data.text_block_with_image_html))
          el(NoteSection, (title: "Additional consequences of those 3 main issues"))
          el(NoteListBlock, (html: data.list_block1_html))
          el(NoteCodeBlock, (code: data.code_block1))
          el(NoteTextBlock, (html: data.text_block1_html))
          el(NoteImagesBlock, (images: data.knots[0..3], tags: @["Knots", "Bushcraft"]))
          el(NoteListBlock, (html: data.list_block1_html))
          el(NoteImagesBlock, (images: data.knots))
          el(NoteListBlock, (html: data.list_block1_html))

  mockup_section("Search"):
    el(LRLayout, ()):
      it.right = els:
        el(RSection, ()) # Adding empty controls, to keep search field same distance from the top
        el(RSection, ()):
          el(RSearchField, (text: "finance/ About Forex"))

      it.left = els:
        el(Search, (title: "Found", more: 23)):
          for i in 1..6:
            el(SearchItem, (
              title: "Risk Simulation",
              subtitle: "",
              before: "there are multiple reasons to",
              match: "About Forex",
              after: "Every single of those reasons is big enough to stay away from " &
                "such investment. Forex has all of them"
            ))

  mockup_section("Misc"):
    el(Message, (text: "Some top level message"))

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
  """.dedent.trim.replace("{html}", render_mockup().to_html(comments = true))
  let dir = current_source_path().parent_dir.absolute_path
  let fname = fmt"{dir}/assets/palette/palette.html"
  fs.write fname, html
  p fmt"{fname} generated"
  say "done"


proc stub_data: StubData =
  result.links = [
    "How to trade safely", "Stock Option Insurance", "Simulating Risk", "Math Modelling"
  ].map((text) => (text, "#"))

  result.tags = {
    "Stock": 1, "Trading": 0, "Market": 2, "Dollar": 0, "Euro": 1,
    "Taxes": 1, "Currency": 0, "Profit": 0, "Loss": 2, "Option": 1,
    "Strategy": 0, "Backtesting": 0
  }.map((t) => (t[0], "#", t[1]))

  result.note_tags = @["Forex", "Margin", "Fake"]

  result.text_block1_html =
    """
      <p>
        There are multiple reasons to About Forex. Every single of those reasons is big enough
        to stay away from such investment. Forex has all of them.
      </p>
    """.dedent.trim.safe_html

  result.text_block2_html =
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
          who controls it. And <code>believes</code> and actions of those who controls it can change suddently
          and because it doesn't has any bottom value, it can fell all the way down to zero.
        </li>
      </ul>
    """.dedent.trim.safe_html

  result.text_block_with_image_html =
    """
      <p>
        Odds are against you. Stock market on average goes up, but
        the currencies on average going down. Small market fluctuation - and the margin call would
        wipe you out.
      </p>

      <p>
        Stock market on average goes up, but the currencies on average going
        down. And <code>believes</code> and actions of those who controls it can change suddently
        and because it doesn't has any bottom value, it can fell all the way down to zero.
        Odds are against you.
      </p>

      <img src="images/msft_chart.png"/>

      <p>
        <b>Leverage</b>. Insane leverage. The minimal transaction on Forex is one lot equal to
        100k$. If you don't have such <a class="text-link" href="#">money</a> - you will be using
        leverage, sometimes very huge leverage. Small market fluctuation - and the margin call would
        wipe you out.
      </p>
    """.dedent.trim.safe_html

  result.list_block1_html =
    """
      <p>
        1.1 No right for a mistake. If you made a mistake on the stock market, if you can
        wait, there's a chance that over time stock will grow back. Not true for Forex.
      </p>

      <p>
        1.2 Currency is a depreciating asset, it looses the value over time. The time plays against you.
      </p>

      <p>
        1.3 Fees. With stock you can buy and hold over long period, paying little transaction fees.
        With Forex keeping currencies doesn't make sense because it's a depreciating asset, so
        there will be probably lots of transactions and lots of fees.
      </p>
    """.dedent.trim.safe_html

  result.code_block1 = """
    palette = Palette.init(mockup_mode = true)
    mockup_section("Text"):
      el(LRLayout, ()):
        it.left = els:
          el(Note, (title: "About Forex", tags: data.note_tags)):
            el(NoteSection, ()):
              el(NoteTextBlock, (html: data.text_block_with_image_html))
  """.dedent.trim

  let dir = current_source_path().parent_dir.absolute_path
  result.knots = fs.read_dir(fmt"{dir}/assets/palette/images/knots")
    .pick(path).mapit("images/knots/" & it.file_name)