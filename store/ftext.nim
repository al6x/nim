import base, ext/parser

type
  FTextItemKind* = enum text, link, tag, embed
  FTextItem* = object
    text*: string
    em*:   Option[bool]
    case kind*: FTextItemKind
    of text:
      discard
    of link:
      link*: string
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


  # FTBlockKind* = enum list, text, section
  # FTextBlock* = object
  #   case kind*: FTBlockKind
  #   of list:
  #     discard
  #   of text:
  #     items: seq[FTextItem]
  #   of section:
  #     discard

  # FTDoc* = object
  #   location*: string
  #   name*:     string
  #   blocks*:   seq[FTextBlock]
  #   tags*:     seq[string]
  #   warnings*: seq[string]




# helpers ------------------------------------------------------------------------------------------
let special_chars        = """`~!@#$%^&*()-_=+[{]}\|;:'",<.>/?""".to_bitset
let space_chars          = "\n\t ".to_bitset
let not_space_chars      = space_chars.complement
let text_chars           = (special_chars + space_chars).complement
# let text_and_space_chars = text_chars + space_chars
let alpha_chars          = {'a'..'z', 'A'..'Z'}
let not_alpha_chars      = alpha_chars.complement
let alphanum_chars       = alpha_chars + {'0'..'9'}


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

proc consume_tags*(pr: Parser, tags: var seq[string]) =
  var unknown = ""
  while true:
    pr.skip((c) => c in tag_delimiter_chars)
    if pr.is_tag:
      let tag = pr.consume_tag
      if tag.is_some: tags.add tag.get
    else:
      if pr.get.is_some: unknown.add pr.get.get
      pr.inc
    if not pr.has_next: break
  if not unknown.is_empty:
    pr.warnings.add fmt"Unknown text in tags: '{unknown}'"

test "consume_tags":
  template t(a, b) =
    let pr = Parser.init(a.dedent); var tags: seq[string]
    pr.consume_tags tags
    check tags == b

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
type HalfParsedBlock = tuple[body: string, kind: string, args: string]

let not_tick_chars           = {'^'}.complement
let not_allowed_in_block_ext = {'}'}

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
  let kind = pr.consume alphanum_chars
  let args = pr.consume (c) => c != '\n'

  if not kind.is_empty:
    blocks.add (body.trim, kind.trim, args.trim) # body could be empty
  else:
    pr.i = start # rolling back

proc consume_blocks*(pr: Parser, blocks: var seq[HalfParsedBlock]) =
  var prev_i = -1
  while true:
    pr.consume_block blocks
    if pr.i == prev_i: break
    prev_i = pr.i

test "consume_blocks, consume_tags":
  template t(a, b, c) =
    let pr = Parser.init(a.dedent); var blocks: seq[HalfParsedBlock]; var tags: seq[string]
    pr.consume_blocks blocks
    pr.consume_tags tags
    check blocks == b
    check tags == c

  t """
    Some text [some link](http://site.com) another text,
    same ^ paragraph.

    Second 2^2 paragraph ^text

    - first m{2^a} line
    - second line ^list

    ^text

    first line

    second line ^list

    some text
    #tag #another ^text

    #tag #another tag
  """, @[
    ("Some text [some link](http://site.com) another text,\nsame ^ paragraph.\n\nSecond 2^2 paragraph", "text", ""),
    ("- first m{2^a} line\n- second line", "list", ""),
    ("", "text", ""),
    ("first line\n\nsecond line", "list", ""),
    ("some text\n#tag #another", "text", "")
  ], @["tag", "another"]

  t """
    some text ^text
  """, @[("some text", "text", "")], seq[string].init

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
    items.add FTextItem(kind: FTextItemKind.link, text: name, link: link)
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
  pr.is_text_paragraph and pr.fget(not_space_chars, 1) == '-'

proc is_text_list_item*(pr: Parser): bool =
  pr.get == '\n' and pr.fget(not_space_chars, 1) == '-'

proc consume_list_item*(pr: Parser): seq[FTextItem] =
  pr.skip space_chars
  assert pr.get == '-'
  pr.inc
  proc stop: bool = pr.is_text_paragraph or pr.is_text_list or pr.is_text_list_item
  pr.consume_inline_text(stop)

proc consume_text_list*(pr: Parser, paragraphs: var seq[FParagraph]) =
  var list: seq[seq[FTextItem]]
  while pr.is_text_list_item:
    let inline_text = pr.consume_list_item
    if not inline_text.is_empty:
      list.add inline_text
  if not list.is_empty:
    paragraphs.add FParagraph(kind: FParagraphKind.list, list: list)


# text ---------------------------------------------------------------------------------------------
proc parse_text*(text: string): seq[FParagraph] =
  let pr = Parser.init(text); var paragraph: seq[FTextItem]

  template finish_paragraph =
    if not paragraph.is_empty:
      result.add FParagraph(kind: FParagraphKind.text, text: paragraph)
      paragraph = seq[FTextItem].init

  proc stop: bool = pr.is_text_paragraph or pr.is_text_list

  while pr.has:
    if   pr.is_text_list:
      pr.consume_text_list result
    elif pr.is_text_paragraph:
      pr.skip_text_paragraph
    else:
      let inline_text = pr.consume_inline_text(stop)
      if not inline_text.is_empty:
        result.add FParagraph(kind: FParagraphKind.text, text: inline_text)


test "parse_text":
  let parsed = """
    Some text [some link](http://site.com) another **text,
    and [link 2]** more #tag1 img{some.png} some `code 2`


    - Line #lt1
    - Line 2 img{some-img}

    And #tag2 another
  """.dedent.parse_text

  check parsed.len == 3

  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # Paragraph 1
    check parsed[0].kind == text
    check parsed[0].text.len == 10
    var it = parsed[0].text
    check it, 0, (kind: "text", text: "Some text")
    check it, 1, (kind: "link", text: "some link", link: "http://site.com")
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


  # p parsed[0].to_json
  # p parsed[1]
  # p parsed[2]

#   var i = 0


# list ---------------------------------------------------------------------------------------------



# proc parse_body_and_tags*(text: string): tuple[body: string, tags: seq[string]] =
#   let text = text.trim
#   let i = text.rfind("\n")
#   if i > 0:
#     var pr = Parser.init(text, i + 1)
#     let tags = pr.parse_tags
#     if pr.is_finished and not tags.is_empty:
#       return (text[0..(i - 1)].trim, tags)
#   (text, @[])

# test "parse_body_and_tags":
#   template t(a, b) = check a.dedent.parse_body_and_tags == b

#   t """
#     some text ^text
#     #a a  #b, #д
#   """, ("some text ^text", @["a a", "b", "д"])

#   t """
#     some #a ^text
#   """, ("some #a ^text", @[])






# # parse_text ---------------------------------------------------------------------------------------










# # # # parse_text_block ---------------------------------------------------------------------------------
# # # # proc parse_text_block*(text: string): seq[JsonNode] =



# # # # parse_list_block ---------------------------------------------------------------------------------

# # # # slow_test "parse_ftext":
# # # #   let dirname = current_source_path().parent_dir
# # # #   let basics = fs.read dirname & "/ftext/basics.ft"
# # # #   parse_ftext(basics)

# # # #   # test with tags and without tags

# # # # let (body_text, tags) = parse_body_and_tags(text)










# # # #   var i = 0
# # # #   while true:
# # # #     if text[i] == "\n"

# # # #   proc parse_token(i: var int): string =
# # # #     var token = ""
# # # #     while i < expression.len and expression[i] notin delimiters:
# # # #       token.add expression[i]
# # # #       i += 1
# # # #     token


# # # #   let (body_text, tags_text) = block:
# # # #     let parts = re"(?si)(.*)\n[\s\n,]*(#[#a-z0-9_\-\s,]+)".parse(text)
# # # #     if   parts.is_none:
# # # #       (text.trim, "")
# # # #     else:
# # # #       (parts.get[0].trim, parts.get[1])

# # # #   # Parsing tags
# # # #   let tags: seq[string] = tags_text
# # # #     .find_all(re"#[a-z0-9_\-\s,]+")
# # # #     .map(trim)
# # # #     .map((tag) => tag.replace(re"[#,]", ""))

# # # #   (body_text, tags)


# # # # Splitting body into blocks
# # #   # let parse_block_re = re"(?si)^(.+? )\^([a-z][a-z0-9_\-]*)$"
# # #   # body_text
# # #   #   .find_all(re"(?si).+? \^[a-z][a-z0-9_-]*(\n|\Z)")
# # #   #   .map(trim)
# # #   #   .map(proc (text: auto): auto =
# # #   #     let (base, ext) = parse_block_re.parse2(text)
# # #   #     (base.trim, ext)
# # #   #   )




# proc consume_text*(pr: Parser, paragraphs: var seq[FParagraph]) =
#   var paragraph: seq[FTextItem]; var text = ""

#   template finish_text =
#     text = text.trim
#     if not text.is_empty:
#       paragraph.add FTextItem(kind: FTextItemKind.text, text: text)
#       text = ""

#   template finish_paragraph =
#     if not paragraph.is_empty:
#       paragraphs.add FParagraph(kind: FParagraphKind.text, text: paragraph)
#       paragraph = seq[FTextItem].init

#   while pr.has:
#     if   pr.is_text_embed:
#       finish_text()
#       pr.consume_text_embed paragraph
#     elif custom():
#       discard
#     elif pr.is_text_list:
#       finish_text()
#       finish_paragraph()
#       # pr.consume_text_list paragraphs
#     elif pr.is_text_paragraph:
#       finish_text()
#       finish_paragraph()
#       pr.skip_text_paragraph
#     elif pr.is_text_link:
#       finish_text()
#       pr.consume_text_link paragraph
#     elif pr.is_tag:
#       finish_text()
#       let tag = pr.consume_tag
#       if tag.is_some: paragraph.add FTextItem(kind: FTextItemKind.tag, text: tag.get)
#     else:
#       text.add pr.get.get
#       pr.inc

#   finish_text()
#   finish_paragraph()