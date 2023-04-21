import base, ext/parser

type
  Warning = tuple[message: string, data: JsonNode]

  Block* = ref object of RootObj
    location*: string
    parent*:   Option[Block]
    text*:     string
    tags*:     seq[string]

  Doc* = ref object of Block
    blocks: seq[Block]


# helpers ------------------------------------------------------------------------------------------
let special_chars        = """`~!@#$%^&*()-_=+[{]}\|;:'",<.>/?""".to_bitset
let space_chars          = "\n\t ".to_bitset
let text_chars           = (special_chars + space_chars).complement
# let text_and_space_chars = text_chars + space_chars
let alpha_chars          = {'a'..'z', 'A'..'Z'}
let alphanum_chars       = alpha_chars + {'0'..'9'}


# parse_tags ---------------------------------------------------------------------------------------
let tag_delimiter_chars = space_chars + {','}
proc parse_tags*(pr: var Parser): seq[string] =
  var unknown = ""
  while true:
    pr.skip((pr) => pr.get in tag_delimiter_chars)
    if pr.get == '#':
      pr.inc
      let tag = pr.collect((pr) => pr.get notin tag_delimiter_chars).trim
      if not tag.is_empty:
        result.add tag
    else:
      if pr.get.is_some: unknown.add pr.get.get
      pr.inc
    if not pr.has_next: break
  if not unknown.is_empty:
    pr.warnings.add ("Unknown text in tags", %{ text: unknown })

test "parse_tags":
  template t(a, b) =
    var pr = Parser.init(a.dedent)
    check pr.parse_tags == b

  t """
    #a a  #b, #д
  """, @["a", "b", "д"]

  t """
    some #a ^text
  """, @["a"]

  t """
    #a ^text #b
  """, @["a", "b"]


# parse_blocks -------------------------------------------------------------------------------------
let not_tick_chars           = {'^'}.complement
let not_allowed_in_block_ext = {'}'}
proc parse_block*(pr: var Parser): Option[tuple[body: string, kind: string, args: string]] =
  let start = pr.i
  let body = pr.collect(proc (pr: auto): bool =
    if pr.get == '^' and (pr.get(1) in alpha_chars):
      for c in pr.items(1): # Looking ahead for newline but not allowing some special characters
        if   c in not_allowed_in_block_ext: return true
        elif c == '\n':                     return false
      return false
    true
  )
  pr.inc
  let kind = pr.collect alphanum_chars
  let args = pr.collect (pr) => pr.get != '\n'

  if not kind.is_empty: # body could be empty
    return (body.trim, kind.trim, args.trim).some
  else:
    pr.i = start # rolling back

proc parse_blocks*(pr: var Parser): seq[tuple[body: string, kind: string, args: string]] =
  while true:
    let blk = pr.parse_block
    if blk.is_some: result.add blk.get
    else:           break

test "parse_blocks and parse_tags":
  template t(a, b, c) =
    var pr = Parser.init(a.dedent)
    check pr.parse_blocks == b
    check pr.parse_tags   == c

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

# parse_text ---------------------------------------------------------------------------------------



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
