import base, ext/[parser, yaml], std/os

type
  FLink* = tuple[space, doc: string]

  FBlock* = ref object of RootObj
    kind*:     string
    id*:       string # If not set explicitly, will be hash of block's text
    args*:     string
    tags*:     seq[string]
    links*:    seq[FLink]
    assets*:   seq[string]
    glinks*:   seq[string]
    text*:     string
    line_n*:   int
    warns*:    seq[string]

  FSection* = ref object
    title*:    string
    blocks*:   seq[FBlock]
    tags*:     seq[string]
    warns*:    seq[string]
    line_n*:   int

  FDoc* = ref object
    id*:          string
    hash*:        int
    location*:    string
    asset_path*:  string # same as location but without .ft extension
    space_path*:  string # location dirname
    title*:       string
    sections*:    seq[FSection]
    tags*:        seq[string]
    tags_line_n*: int
    warns*:       seq[string]

  FTextItemKind* = enum text, link, glink, tag, embed
  FTextItem* = object
    text*: string
    em*:   Option[bool]
    case kind*: FTextItemKind
    of text:
      discard
    of link:
      link*: FLink
    of glink:
      glink*: string
    of tag:
      discard
    of embed:
      embed_kind*: string
      parsed*:     Option[JsonNode]

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

  FCodeBlock* = ref object of FBlock
    code*: string

  FDataBlock* = ref object of FBlock
    data*: JsonNode

  FImageBlock* = ref object of FBlock
    image*: string

  FImagesBlock* = ref object of FBlock
    images_dir*: string
    images*:     seq[string]

  FUnknownBlock* = ref object of FBlock
    raw*: string

type # Config
  HalfParsedBlock = tuple[text: string, kind: string, id: string, args: string, line_n: int]

  FBlockParser* = proc (hblock: HalfParsedBlock, doc: FDoc, config: FTextConfig): FBlock

  # Embed are things like `text image{some.png} text`
  FEmbedParser* = proc (raw: string, blk: FBlock, doc: FDoc, config: FTextConfig): Option[JsonNode]

  FTextConfig* = ref object
    block_parsers*: Table[string, FBlockParser]
    embed_parsers*: Table[string, FEmbedParser]

proc init*(_: type[FDoc], location: string): FDoc =
  assert location.ends_with ".ft"
  let id = location.file_name.file_name_ext.name
  FDoc(id: id, title: id, location: location, asset_path: location[0..^4], space_path: location.parent_dir)

proc fdoc_asset_path*(fdoc_asset_path, relative_path: string): string =
  assert not relative_path.starts_with '/'
  fdoc_asset_path & "/" & relative_path

proc asset_path*(doc: FDoc, relative_path: string): string =
  fdoc_asset_path(doc.asset_path, relative_path)

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

proc line_n(s: string, pos_n: int): int =
  result.inc
  for i in 0..pos_n:
    if pos_n > s.high: break
    if s[i] == '\n': result.inc

proc link_to_s(link: (string, string)): string =
  if link[0] == ".": link[1] else: link[0] & "/" & link[1]

proc hblock(kind, text: string): HalfParsedBlock =
  (text, kind, "", "", 0)

proc map*(list: seq[seq[FTextItem]], map_fn: (FTextItem) -> FTextItem): seq[seq[FTextItem]] =
  for line in list:
    var mline: seq[FTextItem]
    for item in line:
      mline.add map_fn(item)
    result.add mline

proc map*(paragraphs: seq[FParagraph], map_fn: (FTextItem) -> FTextItem): seq[FParagraph] =
  for ph in paragraphs:
    result.add:
      case ph.kind
      of text:
        var mph = FParagraph(kind: text)
        for item in ph.text:
          mph.text.add map_fn(item)
        mph
      of list:
        FParagraph(kind: list, list: ph.list.map(map_fn))

proc each*(list: seq[seq[FTextItem]], fn: (proc (item: FTextItem))) =
  for line in list:
    for item in line:
      fn(item)

proc each*(paragraphs: seq[FParagraph], fn: (proc (item: FTextItem))) =
  for ph in paragraphs:
      case ph.kind
      of text:
        for item in ph.text:
          fn(item)
      of list:
        ph.list.each(fn)

proc normalize_asset_path(path: string, warns: var seq[string]): string =
  if path.is_empty:
    warns.add fmt"Empty path"
    ""
  elif path.starts_with '/':
    warns.add "Path can't be absolute"
    ""
  elif ".." in path:
    warns.add "Path can't have '..'"
    ""
  else:
    path

proc add_text(sentence: var string, text: string) =
  if not sentence.is_empty: sentence.add " "
  sentence.add text

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
    pr.warns.add "Empty tag"

proc consume_tags*(pr: Parser): tuple[tags: seq[string], line_n: int] =
  var unknown = ""; var tags: seq[string]; var tags_start_pos = -1
  while true:
    pr.skip((c) => c in tag_delimiter_chars)
    tags_start_pos = pr.i
    if pr.is_tag:
      let tag = pr.consume_tag
      if tag.is_some: tags.add tag.get
    else:
      if pr.get.is_some: unknown.add pr.get.get
      pr.inc
    if not pr.has_next: break
  if not unknown.is_empty:
    pr.warns.add fmt"Unknown text in tags: '{unknown}'"
  (tags, pr.text.line_n(tags_start_pos))

test "consume_tags":
  template t(a, b) =
    let pr = Parser.init(a.dedent)
    check pr.consume_tags == b

  t """
    #"a a"  #b, #д
  """, (@["a a", "b", "д"], 1)

  t """
    some #a ^text
  """, (@["a"], 1)

  t """
    #a ^text #b
  """, (@["a", "b"], 1)


# blocks -------------------------------------------------------------------------------------------
let not_tick_chars           = {'^'}.complement
let not_allowed_in_block_ext = {'}'}
let block_id_type_chars      = alphanum_chars + {'.'}

proc consume_block*(pr: Parser, blocks: var seq[HalfParsedBlock]) =
  let start = pr.i
  let non_empty_start = pr.i + pr.find(not_space_chars)
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
    if parts.len > 2: pr.warns.add fmt"Wrong block id or kind: '{id_and_kind}'"
    (parts[0], parts[1])
  else:
    ("", id_and_kind)
  let args = pr.consume (c) => c != '\n'

  if not kind.is_empty:
    blocks.add (body.trim, kind.trim, id, args.trim, pr.text.line_n(non_empty_start)) # body could be empty
  else:
    pr.i = start # rolling back

proc consume_blocks*(pr: Parser): seq[HalfParsedBlock] =
  var prev_i = -1
  while true:
    pr.consume_block result
    if pr.i == prev_i: break
    prev_i = pr.i

test "consume_blocks, consume_tags":
  template t(a, expected, tags) =
    let pr = Parser.init(a.dedent)
    var parsed = pr.consume_blocks
    check parsed == expected
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
    ("S t [s l](http://site.com) an t,\nsame ^ par.\n\nSecond 2^2 paragraph", "text", "", "", 1),
    ("- first m{2^a} line\n- second line", "list", "", "", 6),
    ("", "text", "", "", 9),
    ("first line\n\nsecond line", "list", "", "", 11),
    ("k: 1", "data", "config", "", 15),
    ("some text\n#tag #another", "text", "", "", 17)
  ], (@["tag", "another"], 20)

  t """
    some text ^text
  """, @[("some text", "text", "", "", 1)], (seq[string].init, 1)

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

proc parse_local_link(link: string, pr: Parser): (string, string) =
  let parts = link.split("/")
  case parts.len
  of 1:
    (".", parts[0])
  of 2:
    (parts[0], parts[1])
  else:
    pr.warns.add fmt"Invalid link: '{link}'"
    (parts[0], parts[1])

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
      let flink = parse_local_link(link, pr)
      items.add FTextItem(kind: FTextItemKind.link, text: name, link: flink)
    else:
      items.add FTextItem(kind: FTextItemKind.glink, text: name, glink: link)
  else:
    pr.warns.add "Empty link"

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

proc add_text_item_data(blk: FBlock, item: FTextItem): void =
  case item.kind
  of text:
    blk.text.add_text item.text
  of link:
    blk.links.add item.link
    blk.text.add_text item.text
    blk.text.add_text item.link.link_to_s
  of glink:
    blk.glinks.add item.glink
    blk.text.add_text item.text
    blk.text.add_text item.glink
  of tag:
    blk.tags.add item.text
    blk.text.add_text item.text
  of embed:
    discard

proc parse_text*(raw: HalfParsedBlock, doc: FDoc, config: FTextConfig): FTextBlock =
  assert raw.kind == "text"
  let pr = Parser.init raw.text
  let formatted_text = pr.parse_text_as_items
  let blk = FTextBlock(kind: "text", warns: pr.warns)

  proc post_process(item: FTextItem): FTextItem =
    var item = item
    blk.add_text_item_data item # Extracting text
    if item.kind == embed: # Post processing embed items
      if item.embed_kind in config.embed_parsers:
        let eparser: FEmbedParser = config.embed_parsers[item.embed_kind]
        item.parsed = eparser(item.text, blk, doc, config)
      else:
        blk.warns.add fmt"Unknown embed: " & item.embed_kind
    item

  blk.formatted_text = map(formatted_text, post_process)
  blk

proc embed_parser_image(path: string, blk: FBlock, doc: FDoc, config: FTextConfig): Option[JsonNode] =
  let path = normalize_asset_path(path, blk.warns)
  blk.assets.add path
  blk.text.add_text path
  path.to_json.some

proc embed_parser_code(code: string, blk: FBlock, doc: FDoc, config: FTextConfig): Option[JsonNode] =
  blk.text.add_text code

proc test_fdoc_location(): string =
  current_source_path().parent_dir.absolute_path & "/test/some.ft"

proc test_fdoc(): FDoc =
  FDoc.init(location = test_fdoc_location())

test "parse_text":
  let config = FTextConfig()
  config.embed_parsers["image"] = embed_parser_image
  config.embed_parsers["code"] = embed_parser_code

  let ftext = """
    Some text [some link](http://site.com) another **text,
    and [link 2]** more #tag1 image{img.png} some `code 2` some{some}


    - Line #lt1
    - Line 2 image{non_existing.png}

    And #tag2 another
  """.dedent

  let blk = parse_text(hblock("text", ftext), test_fdoc(), config)
  check blk.warns == @["Unknown embed: some"]

  let parsed = blk.formatted_text
  check parsed.len == 3

  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # Paragraph 1
    check parsed[0].kind == text
    check parsed[0].text.len == 11
    var it = parsed[0].text

    check it, 0,  (kind: "text", text: "Some text")
    check it, 1,  (kind: "glink", text: "some link", glink: "http://site.com")
    check it, 2,  (kind: "text", text: "another")
    check it, 3,  (kind: "text", text: "text, and", em: true)
    check it, 4,  (kind: "link", text: "link 2", link: (space: ".", doc: "link 2"), em: true)
    check it, 5,  (kind: "text", text: "more", )
    check it, 6,  (kind: "tag", text: "tag1")
    check it, 7,  (kind: "embed", embed_kind: "image", text: "img.png", parsed: "img.png".some)
    check it, 8,  (kind: "text", text: "some")
    check it, 9,  (kind: "embed", embed_kind: "code", text: "code 2")
    check it, 10, (kind: "embed", embed_kind: "some", text: "some")

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
      (kind: "embed", embed_kind: "image", text: "non_existing.png", parsed: "non_existing.png".some).to_json
    ]

  block: # Paragraph 3
    check parsed[2].kind == text
    check parsed[2].text.len == 3
    var it = parsed[2].text
    check it, 0, (kind: "text", text: "And")
    check it, 1, (kind: "tag", text: "tag2")
    check it, 2, (kind: "text", text: "another")

# list ---------------------------------------------------------------------------------------------
proc parse_list_as_items*(pr: Parser): seq[seq[FTextItem]] =
  if pr.fget(not_space_chars) == '-':
    result = pr.consume_text_list
    pr.skip space_chars
    if pr.has:
      pr.warns.add "Unknown content in list: '" & pr.remainder & "'"
  else:
    while pr.has:
      let inline_text = pr.consume_inline_text(() => pr.is_text_paragraph)
      if not inline_text.is_empty:
        result.add inline_text
      elif pr.is_text_paragraph:
        pr.skip_text_paragraph
      else:
        pr.warns.add "Unknown content in list: '" & pr.remainder & "'"
        break

test "parse_list_as_items":
  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # as list
    let ftext = """
      - Line #tag
      - Line 2 image{some-img}
    """.dedent
    let parsed = Parser.init(ftext).parse_list_as_items

    check parsed.len == 2
    check parsed, 0, [
      (kind: "text", text: "Line"),
      (kind: "tag", text: "tag")
    ]
    check parsed, 1, [
      (kind: "text", text: "Line 2").to_json,
      (kind: "embed", embed_kind: "image", text: "some-img").to_json
    ]

  block: # as paragraphs
    let ftext = """
      Line #tag some
      text

      Line 2 image{some-img}
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
      (kind: "embed", embed_kind: "image", text: "some-img").to_json
    ]

proc parse_list*(raw: HalfParsedBlock, doc: FDoc, config: FTextConfig): FListBlock =
  assert raw.kind == "list"
  let pr = Parser.init raw.text
  let list = pr.parse_list_as_items
  let blk = FListBlock(kind: "list", warns: pr.warns)

  proc post_process(item: FTextItem): FTextItem =
    var item = item
    blk.add_text_item_data item # Extracting text
    if item.kind == embed: # Post processing embed items
      if item.embed_kind in config.embed_parsers:
        let eparser: FEmbedParser = config.embed_parsers[item.embed_kind]
        item.parsed = eparser(item.text, blk, doc, config)
      else:
        blk.warns.add fmt"Unknown embed: '" & item.embed_kind & "'"
    item

  blk.list = map(list, post_process)
  blk

test "parse_list":
  let config = FTextConfig()
  config.embed_parsers["image"] = embed_parser_image
  config.embed_parsers["code"] = embed_parser_code

  let ftext = """
    - Some image{img.png} some{some}
    - Another image{non_existing.png}
  """.dedent

  let blk = parse_list(hblock("list", ftext), test_fdoc(), config)
  check blk.warns == @["Unknown embed: 'some'"]

  let parsed = blk.list
  check parsed.len == 2

  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # Line 1
    var it = parsed[0]
    check it, 0,  (kind: "text", text: "Some")
    check it, 1,  (kind: "embed", embed_kind: "image", text: "img.png", parsed: "img.png".some)
    check it, 2,  (kind: "embed", embed_kind: "some", text: "some")

  block: # Line 2
    var it = parsed[1]
    check it, 0,  (kind: "text", text: "Another")
    check it, 1,  (kind: "embed", embed_kind: "image", text: "non_existing.png", parsed: "non_existing.png".some)

# data ---------------------------------------------------------------------------------------------
proc parse_data*(raw: HalfParsedBlock): FDataBlock =
  assert raw.kind == "data"
  let json = parse_yaml raw.text
  FDataBlock(kind: "data", data: json, text: raw.text)

# section ------------------------------------------------------------------------------------------
proc parse_section*(raw: HalfParsedBlock): FSection =
  assert raw.kind == "section"
  let pr = Parser.init raw.text
  let formatted_text = pr.consume_inline_text () => false
  result = FSection(line_n: raw.line_n)
  if pr.has_next: result.warns.add fmt"Invalid text in section : '{pr.remainder}'"
  var texts: seq[string]
  for item in formatted_text:
    case item.kind
    of text: texts.add item.text
    of tag:  result.tags.add item.text
    else:
      result.warns.add fmt"Invalid text in section : '{pr.remainder}'"
  result.title = texts.join " "
  if result.title.is_empty: result.warns.add fmt"Empty section title"

# title --------------------------------------------------------------------------------------------
proc parse_title*(raw: HalfParsedBlock): string =
  assert raw.kind == "title"
  raw.text

# proc extract_title_from_location(location: string): string =
#   location.split("/").last.replace(re"\.[a-zA-Z0-9]+", "")

# code ---------------------------------------------------------------------------------------------
proc parse_code*(raw: HalfParsedBlock): FCodeBlock =
  assert raw.kind == "code"
  FCodeBlock(kind: "code", code: raw.text.trim, text: raw.text.trim)

# image, images ------------------------------------------------------------------------------------
proc parse_path_and_tags(text: string, warns: var seq[string]): tuple[path: string, tags: seq[string]] =
  let parts = text.split("#", maxsplit = 1)
  var path = parts[0].trim; var warns, tags: seq[string]
  path = normalize_asset_path(path, warns)
  if parts.len > 1:
    let pr = Parser.init("#" & parts[1])
    tags = pr.consume_tags.tags
    if pr.has:
      warns.add "Unknown content in image: '" & pr.remainder & "'"
  (path, tags)

proc parse_image*(raw: HalfParsedBlock, doc: FDoc): FImageBlock =
  assert raw.kind == "image"
  var warns: seq[string]
  let (path, tags) = parse_path_and_tags(raw.text, warns)
  var assets: seq[string]
  unless path.is_empty: assets.add path
  FImageBlock(kind: "image", image: path, tags: tags, warns: warns, text: raw.text, assets: assets)

proc parse_images*(raw: HalfParsedBlock, doc: FDoc): FImagesBlock =
  assert raw.kind == "images"
  var warns: seq[string]
  let (path, tags) = parse_path_and_tags(raw.text, warns)
  result = FImagesBlock(images_dir: path, kind: "images", tags: tags, warns: warns, text: raw.text)
  unless path.is_empty:
    result.assets = @[path]
    let images_path = asset_path(doc, path)
    proc normalise_asset_path(fname: string): string =
      if path == ".": fname else: path & "/" & fname
    result.images = fs.read_dir(images_path)
      .filter((entry) => entry.kind == file).pick(name).map(normalise_asset_path).sort
    result.assets.add result.images

test "image":
  let img = parse_image(hblock("image", "some.png #t1 #t2"), test_fdoc())
  check (img.image, img.tags, img.assets) == ("some.png", @["t1", "t2"], @["some.png"])

test "images, missing":
  let imgs = parse_images(hblock("images", "missing/dir\n#t1 #t2"), test_fdoc())
  check (imgs.images_dir, imgs.images, imgs.tags, imgs.assets) == ("missing/dir", @[], @["t1", "t2"],
    @["missing/dir"])

test "images":
  let imgs = parse_images(hblock("images", ". #t1 #t2"), test_fdoc())
  check (imgs.images_dir, imgs.images, imgs.tags, imgs.assets) == (".", @["img.png"], @["t1", "t2"],
    @[".", "img.png"])

# FTextConfig --------------------------------------------------------------------------------------
proc init*(_: type[FTextConfig]): FTextConfig =
  var block_parsers: Table[string, FBlockParser]
  block_parsers["text"]   = (blk, doc, config) => parse_text(blk, doc, config)
  block_parsers["list"]   = (blk, doc, config) => parse_list(blk, doc, config)
  block_parsers["data"]   = (blk, doc, config) => parse_data(blk)
  block_parsers["code"]   = (blk, doc, config) => parse_code(blk)
  block_parsers["image"]  = (blk, doc, config) => parse_image(blk, doc)
  block_parsers["images"] = (blk, doc, config) => parse_images(blk, doc)

  var embed_parsers: Table[string, FEmbedParser]
  embed_parsers["image"] = embed_parser_image
  embed_parsers["code"]  = embed_parser_code

  FTextConfig(block_parsers: block_parsers, embed_parsers: embed_parsers)

let default_config = FTextConfig.init

# parse_ftext --------------------------------------------------------------------------------------
proc post_process_block(blk: FBlock, doc: FDoc, config: FTextConfig) =
  for rpath in blk.assets:
    assert not rpath.is_empty, "asset can't be empty"
    unless fs.exist(asset_path(doc, rpath)):
      blk.warns.add fmt"Asset don't exist {doc.id}/{rpath}"

proc parse_ftext*(text, location: string, config = default_config): FDoc =
  let pr = Parser.init(text)
  let raw_blocks = pr.consume_blocks
  let (tags, tags_line_n) = pr.consume_tags
  let doc = FDoc.init location
  doc.hash = text.hash.int; doc.tags = tags; doc.tags_line_n = tags_line_n
  for raw in raw_blocks:
    if   raw.kind == "title":
      doc.title = parse_title raw
    elif raw.kind == "section":
      let section = parse_section raw
      doc.sections.add section
    else:
      if doc.sections.is_empty: doc.sections.add FSection(line_n: 1)
      doc.sections[^1].blocks.add:
        if raw.kind in config.block_parsers:
          let blk = config.block_parsers[raw.kind](raw, doc, config)
          blk.id = raw.id; blk.args = raw.args; blk.line_n = raw.line_n
          post_process_block(blk, doc, config)
          blk
        else:
          let blk = FUnknownBlock(kind: raw.kind, raw: raw.text, id: raw.id, args: raw.args, text: raw.text)
          doc.warns.add fmt"Unknown block '{blk.kind}'"
          blk
  doc

test "parse_ftext":
  block:
    let text = """
      Some #tag text ^text

      - a
      - b ^list

      k: 1 ^config.data

      #t #t2
    """.dedent

    let doc = parse_ftext(text, "some.ft")
    check doc.sections.len == 1
    let section = doc.sections[0]
    check section.blocks.len == 3
    check section.line_n == 1
    check doc.tags == @["t", "t2"]
    check doc.tags_line_n == 8

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

    let doc = parse_ftext(text, "some.ft")
    check doc.title == "Some title"
    check doc.sections.len == 2
    check doc.sections[0].line_n == 3
    check doc.sections[1].line_n == 7

test "parse_ftext, missing assets":
  let text = """
    image{missing1.png} ^text

    missing2.png ^image

    missing_dir ^images
  """.dedent

  let doc = parse_ftext(text, test_fdoc_location())
  let blocks = doc.sections[0].blocks
  check blocks.len == 3
  check blocks[0].warns == @["Asset don't exist some/missing1.png"]
  check blocks[1].warns == @["Asset don't exist some/missing2.png"]
  check blocks[2].warns == @["Asset don't exist some/missing_dir"]