import base, ext/parser

type
  FTextItemKind* = enum text, link, tag, embed, paragraph
  FTextItem* = object
    text*: string
    case kind*: FTextItemKind
    of text:
      discard
    of link:
      link*: string
    of tag:
      discard
    of embed:
      embed_kind*: string
    of paragraph:
      discard

  FTBlockKind* = enum list, text, section
  FTextBlock* = object
    case kind*: FTBlockKind
    of list:
      discard
    of text:
      items: seq[FTextItem]
    of section:
      discard

  FTDoc* = object
    location*: string
    name*:     string
    blocks*:   seq[FTextBlock]
    tags*:     seq[string]
    warnings*: seq[string]




# helpers ------------------------------------------------------------------------------------------
let special_chars        = """`~!@#$%^&*()-_=+[{]}\|;:'",<.>/?""".to_bitset
let space_chars          = "\n\t ".to_bitset
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

proc consume_tag*(pr: var Parser): Option[string] =
  assert pr.get == '#'
  pr.inc
  var tag: string
  if pr.get == '"':
    pr.inc
    tag = pr.consume((pr) => pr.get notin quoted_tag_end_chars).trim
    if pr.get == '"': pr.inc
  else:
    tag = pr.consume((pr) => pr.get notin tag_delimiter_chars).trim
  if not tag.is_empty:
    result = tag.some
  else:
    pr.warnings.add "Empty tag"

proc consume_tags*(pr: var Parser, tags: var seq[string]) =
  var unknown = ""
  while true:
    pr.skip((pr) => pr.get in tag_delimiter_chars)
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
    var pr = Parser.init(a.dedent); var tags: seq[string]
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

proc consume_block*(pr: var Parser, blocks: var seq[HalfParsedBlock]) =
  let start = pr.i
  let body = pr.consume(proc (pr: auto): bool =
    if pr.get == '^' and (pr.get(1) in alpha_chars):
      for c in pr.items(1): # Looking ahead for newline but not allowing some special characters
        if   c in not_allowed_in_block_ext: return true
        elif c == '\n':                     return false
      return false
    true
  )
  pr.inc
  let kind = pr.consume alphanum_chars
  let args = pr.consume (pr) => pr.get != '\n'

  if not kind.is_empty:
    blocks.add (body.trim, kind.trim, args.trim) # body could be empty
  else:
    pr.i = start # rolling back

proc consume_blocks*(pr: var Parser, blocks: var seq[HalfParsedBlock]) =
  var prev_i = -1
  while true:
    pr.consume_block blocks
    if pr.i == prev_i: break
    prev_i = pr.i

test "consume_blocks, consume_tags":
  template t(a, b, c) =
    var pr = Parser.init(a.dedent); var blocks: seq[HalfParsedBlock]; var tags: seq[string]
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
  pr.get in alpha_chars and pr.fget(not_alpha_chars) == '{'

proc consume_text_embed*(pr: var Parser, items: var seq[FTextItem]) =
  assert pr.get in alpha_chars
  let kind = pr.consume alpha_chars
  assert pr.get == '{'
  var brackets = 0; var body = ""
  while pr.has:
    if   pr.get == '{': brackets.inc
    elif pr.get == '}': brackets.dec
    body.add pr.get.get
    pr.inc
    if brackets == 0:
      break
  body = body.replace(re"^\{|\}$", "")
  items.add FTextItem(kind: embed, embed_kind: kind, text: body)

test "text_embed":
  var pr = Parser.init "math{2^{2}}"; var items: seq[FTextItem]
  check pr.is_text_embed == true
  pr.consume_text_embed items
  check items.to_json == @[FTextItem(kind: embed, embed_kind: "math", text: "2^{2}")].to_json

# text_link ----------------------------------------------------------------------------------------
proc is_text_link*(pr: Parser): bool =
  pr.get == '['

let link_chars = {']', ')', '\n'}.complement
proc consume_text_link*(pr: var Parser, items: var seq[FTextItem]) =
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


# text_paragraph -----------------------------------------------------------------------------------
proc is_text_paragraph*(pr: Parser): bool =
  pr.get == '\n' and pr.fget(space_chars, 1) == '\n'

proc consume_text_paragraph*(pr: var Parser, items: var seq[FTextItem]) =
  assert pr.get == '\n'
  let text = pr.consume space_chars
  items.add FTextItem(kind: paragraph, text: text)

# text ---------------------------------------------------------------------------------------------
proc parse_text*(text: string): seq[FTextItem] =
  var pr = Parser.init text; var text = ""
  template finish_text =
    text = text.trim
    if not text.is_empty:
      result.add FTextItem(kind: FTextItemKind.text, text: text)
      text = ""

  while pr.has:
    if   pr.is_text_embed:
      finish_text()
      pr.consume_text_embed result
    elif pr.is_text_link:
      finish_text()
      pr.consume_text_link result
    elif pr.is_tag:
      finish_text()
      let tag = pr.consume_tag
      if tag.is_some: result.add FTextItem(kind: FTextItemKind.tag, text: tag.get)
    elif pr.is_text_paragraph:
      finish_text()
      pr.consume_text_paragraph result
    else:
      text.add pr.get.get
      pr.inc
  finish_text()

# test "parse_text":
  # template t(a, b, c) =
  #   var pr = Parser.init(a.dedent); var blocks: seq[HalfParsedBlock]; var tags: seq[string]
  #   pr.consume_blocks blocks
  #   pr.consume_tags tags
  #   check blocks == b
  #   check tags == c

p """
  Some text [some link](http://site.com) another text
  and #tag1 img{some.png}

  And text #tag2
""".parse_text

# section ------------------------------------------------------------------------------------------

# code ---------------------------------------------------------------------------------------------



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
