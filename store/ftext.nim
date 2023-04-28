import base, ext/[parser, yaml]

type
  FBlock* = ref object of RootObj
    kind*:     string
    id*:       string
    args*:     string
    tags*:     seq[string]
    links*:    seq[string]
    glinks*:   seq[string]
    text*:     string
    warnings*: seq[string]

  FSection* = object
    title*:    string
    blocks*:   seq[FBlock]
    tags*:     seq[string]
    warnings*: seq[string]

  FDoc* = object
    location*: string
    title*:    string
    sections*: seq[FSection]
    tags*:     seq[string]
    warnings*: seq[string]

  FTextItemKind* = enum text, link, glink, tag, embed
  FTextItem* = object
    text*: string
    em*:   Option[bool]
    case kind*: FTextItemKind
    of text:
      discard
    of link:
      link*: string
    of glink:
      glink*: string
    of tag:
      discard
    of embed:
      embed_kind*: string

  FParagraphKind* = enum text, list
  FParagraph* = object
    case kind*: FParagraphKind
    of text:
      text*: seq[FTextItem]
    of list:
      list*: seq[seq[FTextItem]]

  FTextBlock* = ref object of FBlock
    formatted_text*: seq[FParagraph]

  FListBlock* = ref object of FBlock
    list*: seq[seq[FTextItem]]

  FDataBlock* = ref object of FBlock
    data*: JsonNode

  FUnknownBlock* = ref object of FBlock
    raw*: string

  HalfParsedBlock = tuple[text: string, kind: string, id: string, args: string]

type FBlockParser* = (HalfParsedBlock) -> FBlock
let  fblock_parsers* = (ref Table[string, FBlockParser])()

# helpers ------------------------------------------------------------------------------------------
let special_chars        = """`~!@#$%^&*()-_=+[{]}\|;:'",<.>/?""".to_bitset
let space_chars          = "\n\t ".to_bitset
let not_space_chars      = space_chars.complement
let text_chars           = (special_chars + space_chars).complement
# let text_and_space_chars = text_chars + space_chars
let alpha_chars          = {'a'..'z', 'A'..'Z'}
let not_alpha_chars      = alpha_chars.complement
let alphanum_chars       = alpha_chars + {'0'..'9'}

iterator items(ph: FParagraph): FTextItem =
  if ph.kind == text:
    for item in ph.text: yield item
  else:
    for line in ph.list:
      for item in line: yield item

# tags ---------------------------------------------------------------------------------------------
let tag_delimiter_chars  = space_chars + {','}
let quoted_tag_end_chars = {'\n', '"'}
proc is_tag*(pr: Parser): bool =
  pr.get == '#'

proc consume_tag*(pr: Parser): Option[string] =
  assert pr.get == '#'
  pr.inc
  var tag: string
  if pr.get == '"':
    pr.inc
    tag = pr.consume((c) => c notin quoted_tag_end_chars).trim
    if pr.get == '"': pr.inc
  else:
    tag = pr.consume((c) => c notin tag_delimiter_chars).trim
  if not tag.is_empty:
    result = tag.some
  else:
    pr.warnings.add "Empty tag"

proc consume_tags*(pr: Parser): seq[string] =
  var unknown = ""
  while true:
    pr.skip((c) => c in tag_delimiter_chars)
    if pr.is_tag:
      let tag = pr.consume_tag
      if tag.is_some: result.add tag.get
    else:
      if pr.get.is_some: unknown.add pr.get.get
      pr.inc
    if not pr.has_next: break
  if not unknown.is_empty:
    pr.warnings.add fmt"Unknown text in tags: '{unknown}'"

test "consume_tags":
  template t(a, b) =
    let pr = Parser.init(a.dedent)
    check pr.consume_tags == b

  t """
    #"a a"  #b, #д
  """, @["a a", "b", "д"]

  t """
    some #a ^text
  """, @["a"]

  t """
    #a ^text #b
  """, @["a", "b"]


# blocks -------------------------------------------------------------------------------------------
let not_tick_chars           = {'^'}.complement
let not_allowed_in_block_ext = {'}'}
let block_id_type_chars      = alphanum_chars + {'.'}

proc consume_block*(pr: Parser, blocks: var seq[HalfParsedBlock]) =
  let start = pr.i
  let body = pr.consume(proc (c: auto): bool =
    if c == '^' and (pr.get(1) in alpha_chars):
      for v in pr.items(1): # Looking ahead for newline but not allowing some special characters
        if   v in not_allowed_in_block_ext: return true
        elif v == '\n':                     return false
      return false
    true
  )
  pr.inc
  let id_and_kind = pr.consume block_id_type_chars
  let (id, kind) = if '.' in id_and_kind:
    let parts = id_and_kind.split '.'
    if parts.len > 2: pr.warnings.add fmt"Wrong block id or kind: '{id_and_kind}'"
    (parts[0], parts[1])
  else:
    ("", id_and_kind)
  let args = pr.consume (c) => c != '\n'

  if not kind.is_empty:
    blocks.add (body.trim, kind.trim, id, args.trim) # body could be empty
  else:
    pr.i = start # rolling back

proc consume_blocks*(pr: Parser): seq[HalfParsedBlock] =
  var prev_i = -1
  while true:
    pr.consume_block result
    if pr.i == prev_i: break
    prev_i = pr.i

test "consume_blocks, consume_tags":
  template t(a, blocks, tags) =
    let pr = Parser.init(a.dedent)
    check pr.consume_blocks == blocks
    check pr.consume_tags == tags

  t """
    S t [s l](http://site.com) an t,
    same ^ par.

    Second 2^2 paragraph ^text

    - first m{2^a} line
    - second line ^list

    ^text

    first line

    second line ^list

    k: 1 ^config.data

    some text
    #tag #another ^text

    #tag #another tag
  """, @[
    ("S t [s l](http://site.com) an t,\nsame ^ par.\n\nSecond 2^2 paragraph", "text", "", ""),
    ("- first m{2^a} line\n- second line", "list", "", ""),
    ("", "text", "", ""),
    ("first line\n\nsecond line", "list", "", ""),
    ("k: 1", "data", "config", ""),
    ("some text\n#tag #another", "text", "", "")
  ], @["tag", "another"]

  t """
    some text ^text
  """, @[("some text", "text", "", "")], seq[string].init

# text_embedding -----------------------------------------------------------------------------------
proc is_text_embed*(pr: Parser): bool =
  (pr.get in alpha_chars and pr.fget(not_alpha_chars) == '{') or pr.get == '`'

proc consume_text_embed*(pr: Parser, items: var seq[FTextItem]) =
  # Consumes `some{text}` or `text`
  let (kind, body) = if pr.get in alpha_chars:
    let kind = pr.consume alpha_chars
    assert pr.get == '{'
    var brackets = 0; var body = ""
    while pr.has:
      if   pr.get == '{': brackets.inc
      elif pr.get == '}': brackets.dec
      body.add pr.get.get
      pr.inc
      if brackets == 0: break
    (kind, body.replace(re"^\{|\}$", ""))
  elif pr.get == '`':
    pr.inc
    let body = pr.consume((c) => c != '`')
    pr.inc
    ("code", body)
  else:
    throw "invalid text embed"
  items.add FTextItem(kind: embed, embed_kind: kind, text: body)

test "text_embed":
  template t(a, b) =
    let pr = Parser.init(a); var items: seq[FTextItem]
    check pr.is_text_embed == true
    pr.consume_text_embed items
    assert items.len == 1
    check items[0].to_json == b.to_json

  t "math{2^{2} } other", FTextItem(kind: embed, embed_kind: "math", text: "2^{2} ")
  t "`2^{2} ` other",     FTextItem(kind: embed, embed_kind: "code", text: "2^{2} ")

# text_link ----------------------------------------------------------------------------------------
proc is_text_link*(pr: Parser): bool =
  pr.get == '['

proc is_local_link(link: string): bool =
  # If link is a local or global link
  assert not link.is_empty
  "://" notin link

let link_chars = {']', ')', '\n'}.complement
proc consume_text_link*(pr: Parser, items: var seq[FTextItem]) =
  assert pr.get == '['
  pr.inc
  let name = pr.consume link_chars
  if pr.get == ']': pr.inc

  var link = name
  if pr.get in {'[', '('}:
    pr.inc
    link = pr.consume link_chars
    if pr.get in {']', ')'}: pr.inc

  if not link.is_empty:
    if link.is_local_link:
      items.add FTextItem(kind: FTextItemKind.link, text: name, link: link)
    else:
      items.add FTextItem(kind: FTextItemKind.glink, text: name, glink: link)
  else:
    pr.warnings.add "Empty link"

# em -----------------------------------------------------------------------------------------------
proc is_em(pr: Parser): bool =
  pr.get == '*' and pr.get(1) == '*'

proc consume_em(pr: Parser) =
  assert pr.get == '*'
  pr.inc
  assert pr.get == '*'
  pr.inc

# inline_text --------------------------------------------------------------------------------------
proc consume_inline_text*(pr: Parser, stop: (proc: bool)): seq[FTextItem] =
  var text = ""; var em_started_i: int = -1

  template finish_text =
    text = text.replace(re"[\s\n]+", " ").trim
    if not text.is_empty:
      result.add FTextItem(kind: FTextItemKind.text, text: text)
      text = ""

  while pr.has:
    if   stop():
      break
    elif pr.is_text_embed:
      finish_text()
      pr.consume_text_embed result
    elif pr.is_em:
      finish_text()
      pr.consume_em
      if em_started_i >= 0:
        if em_started_i < result.len:
          for i in (em_started_i..result.high):
            result[i].em = true.some
        em_started_i = -1
      else:
        em_started_i = result.len
    elif pr.is_text_link:
      finish_text()
      pr.consume_text_link(result)
    elif pr.is_tag:
      finish_text()
      let tag = pr.consume_tag
      if tag.is_some: result.add FTextItem(kind: FTextItemKind.tag, text: tag.get)
    else:
      text.add pr.get.get
      pr.inc

  finish_text()

# text_paragraph -----------------------------------------------------------------------------------
let not_st_chars = {' ', '\t'}.complement
proc is_text_paragraph*(pr: Parser): bool =
  pr.get == '\n' and pr.fget(not_st_chars, 1) == '\n'

proc skip_text_paragraph*(pr: Parser) =
  assert pr.get == '\n'
  pr.skip space_chars

# text_list ----------------------------------------------------------------------------------------
proc is_text_list*(pr: Parser): bool =
  (pr.i == 0 or pr.is_text_paragraph) and pr.fget(not_space_chars) == '-'

proc is_text_list_item*(pr: Parser): bool =
  (pr.i == 0 or pr.get == '\n') and pr.fget(not_space_chars) == '-'

proc consume_list_item*(pr: Parser): seq[FTextItem] =
  pr.skip space_chars
  assert pr.get == '-'
  pr.inc
  proc stop: bool = pr.is_text_paragraph or pr.is_text_list or pr.is_text_list_item
  pr.consume_inline_text(stop)

proc consume_text_list*(pr: Parser): seq[seq[FTextItem]] =
  while pr.is_text_list_item:
    let inline_text = pr.consume_list_item
    if not inline_text.is_empty:
      result.add inline_text

# text ---------------------------------------------------------------------------------------------
proc parse_text_as_items*(pr: Parser): seq[FParagraph] =
  var paragraph: seq[FTextItem]

  template finish_paragraph =
    if not paragraph.is_empty:
      result.add FParagraph(kind: FParagraphKind.text, text: paragraph)
      paragraph = seq[FTextItem].init

  proc stop: bool = pr.is_text_paragraph or pr.is_text_list

  while pr.has:
    if   pr.is_text_list:
      let items = pr.consume_text_list
      if not items.is_empty:
        result.add FParagraph(kind: list, list: items)
    elif pr.is_text_paragraph:
      pr.skip_text_paragraph
    else:
      let inline_text = pr.consume_inline_text(stop)
      if not inline_text.is_empty:
        result.add FParagraph(kind: FParagraphKind.text, text: inline_text)

test "parse_text_as_items":
  let ftext = """
    Some text [some link](http://site.com) another **text,
    and [link 2]** more #tag1 img{some.png} some `code 2`


    - Line #lt1
    - Line 2 img{some-img}

    And #tag2 another
  """.dedent
  let parsed = Parser.init(ftext).parse_text_as_items

  check parsed.len == 3

  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # Paragraph 1
    check parsed[0].kind == text
    check parsed[0].text.len == 10
    var it = parsed[0].text
    check it, 0, (kind: "text", text: "Some text")
    check it, 1, (kind: "glink", text: "some link", glink: "http://site.com")
    check it, 2, (kind: "text", text: "another")
    check it, 3, (kind: "text", text: "text, and", em: true)
    check it, 4, (kind: "link", text: "link 2", link: "link 2", em: true)
    check it, 5, (kind: "text", text: "more", )
    check it, 6, (kind: "tag", text: "tag1")
    check it, 7, (kind: "embed", embed_kind: "img", text: "some.png")
    check it, 8, (kind: "text", text: "some")
    check it, 9, (kind: "embed", embed_kind: "code", text: "code 2")

  block: # Paragraph 2
    check parsed[1].kind == list
    check parsed[1].list.len == 2
    var it = parsed[1].list
    check it, 0, [
      (kind: "text", text: "Line"),
      (kind: "tag", text: "lt1")
    ]
    check it, 1, [
      (kind: "text", text: "Line 2").to_json,
      (kind: "embed", embed_kind: "img", text: "some-img").to_json
    ]

  block: # Paragraph 3
    check parsed[2].kind == text
    check parsed[2].text.len == 3
    var it = parsed[2].text
    check it, 0, (kind: "text", text: "And")
    check it, 1, (kind: "tag", text: "tag2")
    check it, 2, (kind: "text", text: "another")

proc add_text_item_data(blk: FBlock, item: FTextItem): void =
  template add_text(txt) =
    if not blk.text.is_empty: blk.text.add " "
    blk.text.add txt

  case item.kind
  of text:
    add_text item.text
  of link:
    blk.links.add item.link
    add_text item.text
    add_text item.link
  of glink:
    blk.glinks.add item.link
    add_text item.text
    add_text item.glink
  of tag:
    blk.tags.add item.text
    add_text item.text
  of embed:
    discard

proc parse_text*(raw: HalfParsedBlock): FTextBlock =
  assert raw.kind == "text"
  let pr = Parser.init raw.text
  let formatted_text = pr.parse_text_as_items
  result = FTextBlock(
    kind: "text", id: raw.id, args: raw.args, warnings: pr.warnings, formatted_text: formatted_text
  )
  for ph in formatted_text:
    for item in ph:
      result.add_text_item_data item

fblock_parsers["text"] = (blk) => parse_text(blk)

# list ---------------------------------------------------------------------------------------------
proc parse_list_as_items*(pr: Parser): seq[seq[FTextItem]] =
  if pr.fget(not_space_chars) == '-':
    result = pr.consume_text_list
    pr.skip space_chars
    if pr.has:
      pr.warnings.add "Unknown content in list: '" & pr.remainder & "'"
  else:
    while pr.has:
      let inline_text = pr.consume_inline_text(() => pr.is_text_paragraph)
      if not inline_text.is_empty:
        result.add inline_text
      elif pr.is_text_paragraph:
        pr.skip_text_paragraph
      else:
        pr.warnings.add "Unknown content in list: '" & pr.remainder & "'"
        break

test "parse_list_as_items":
  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # as list
    let ftext = """
      - Line #tag
      - Line 2 img{some-img}
    """.dedent
    let parsed = Parser.init(ftext).parse_list_as_items

    check parsed.len == 2
    check parsed, 0, [
      (kind: "text", text: "Line"),
      (kind: "tag", text: "tag")
    ]
    check parsed, 1, [
      (kind: "text", text: "Line 2").to_json,
      (kind: "embed", embed_kind: "img", text: "some-img").to_json
    ]

  block: # as paragraphs
    let ftext = """
      Line #tag some
      text

      Line 2 img{some-img}
    """.dedent
    let parsed = Parser.init(ftext).parse_list_as_items

    check parsed.len == 2
    check parsed, 0, [
      (kind: "text", text: "Line"),
      (kind: "tag", text: "tag"),
      (kind: "text", text: "some text")
    ]
    check parsed, 1, [
      (kind: "text", text: "Line 2").to_json,
      (kind: "embed", embed_kind: "img", text: "some-img").to_json
    ]

proc parse_list*(raw: HalfParsedBlock): FListBlock =
  assert raw.kind == "list"
  let pr = Parser.init raw.text
  let list = pr.parse_list_as_items
  result = FListBlock(kind: "list", id: raw.id, args: raw.args, warnings: pr.warnings, list: list)
  for line in list:
    for item in line:
      result.add_text_item_data item

fblock_parsers["list"] = (blk) => parse_list(blk)

# data ---------------------------------------------------------------------------------------------
proc parse_data*(raw: HalfParsedBlock): FDataBlock =
  assert raw.kind == "data"
  let json = parse_yaml raw.text
  FDataBlock(kind: "data", data: json, id: raw.id, args: raw.args, text: raw.text)

fblock_parsers["data"] = (blk) => parse_data(blk)

# section ------------------------------------------------------------------------------------------
proc parse_section*(raw: HalfParsedBlock): FSection =
  assert raw.kind == "section"
  let pr = Parser.init raw.text
  let formatted_text = pr.consume_inline_text () => false
  result = FSection()
  if pr.has_next: result.warnings.add fmt"Invalid text in section : '{pr.remainder}'"
  var texts: seq[string]
  for item in formatted_text:
    case item.kind
    of text: texts.add item.text
    of tag:  result.tags.add item.text
    else:
      result.warnings.add fmt"Invalid text in section : '{pr.remainder}'"
  result.title = texts.join " "
  if result.title.is_empty: result.warnings.add fmt"Empty section title"

# fblock_parsers["section"] = (blk) => parse_section(blk)

# title --------------------------------------------------------------------------------------------
proc parse_title*(raw: HalfParsedBlock): string =
  assert raw.kind == "title"
  raw.text

proc extract_title_from_location(location: string): string =
  location.split("/").last.replace(re"\.[a-zA-Z0-9]+", "")

# parse_ftext --------------------------------------------------------------------------------------
proc parse_ftext*(text: string, location = ""): FDoc =
  let pr = Parser.init(text)
  let raw_blocks = pr.consume_blocks
  let tags = pr.consume_tags
  result = FDoc(location: location, tags: tags, title: extract_title_from_location(location))
  for raw in raw_blocks:
    if   raw.kind == "title":
      result.title = parse_title raw
    elif raw.kind == "section":
      let section = parse_section raw
      result.sections.add section
      result.warnings.add section.warnings
    else:
      if result.sections.is_empty: result.sections.add FSection()
      if raw.kind in fblock_parsers:
        let blk = fblock_parsers[raw.kind](raw)
        result.sections[^1].blocks.add blk
        result.warnings.add blk.warnings
      else:
        let blk = FUnknownBlock(kind: raw.kind, raw: raw.text, id: raw.id, args: raw.args, text: raw.text)
        result.sections[^1].blocks.add blk
        result.warnings.add fmt"Unknown block '{blk.kind}'"

test "parse_ftext":
  block:
    let text = """
      Some #tag text ^text

      - a
      - b ^list

      k: 1 ^config.data

      #t #t2
    """.dedent

    let doc = parse_ftext text
    check doc.sections.len == 1
    check doc.sections[0].blocks.len == 3
    check doc.tags == @["t", "t2"]

  block:
    let text = """
      Some title ^title

      Some section ^section

      Some #tag text #t1 ^text

      Another section
      #t1 #t2 ^section

      - a
      - b ^list

      k: 1 ^data

      #t #t2
    """.dedent

    let doc = parse_ftext text
    check doc.title == "Some title"
    check doc.sections.len == 2