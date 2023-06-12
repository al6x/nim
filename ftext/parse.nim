import base, ext/[parser, yaml]
import ./model

export model

type # Config
  FBlockParser* = proc (source: FBlockSource, doc: Doc, config: FParseConfig): Block

  # Embed are things like `text image{some.png} text`
  FEmbedParser* = proc (raw: string, blk: Block, doc: Doc, config: FParseConfig): Embed

  FParseConfig* = ref object
    can_have_implicittext*: seq[string] # Blocks that may contain implicit text block before
    block_parsers*:         Table[string, FBlockParser]
    embed_parsers*:         Table[string, FEmbedParser]

# helpers ------------------------------------------------------------------------------------------
let special_chars        = """`~!@#$%^&*()-_=+[{]}\|;:'",<.>/?""".to_bitset
let space_chars          = "\n\t ".to_bitset
let not_space_chars      = space_chars.complement
let text_chars           = (special_chars + space_chars).complement
# let text_and_space_chars = text_chars + space_chars
let alpha_chars          = {'a'..'z', 'A'..'Z'}
let not_alpha_chars      = alpha_chars.complement
let alphanum_chars       = alpha_chars + {'0'..'9'}

const lookahead_limit = 32 # How much to look ahead, if it's too large parsing will be slow

iterator items(ph: Paragraph): TextItem =
  if ph.kind == text:
    for item in ph.text: yield item
  else:
    for line in ph.list:
      for item in line: yield item

proc line_n(s: string, pos_n: int): int =
  result.inc # lines start with 1
  for i in 0..s.high:
    if i > pos_n: break
    if s[i] == '\n': result.inc

proc map*(list: seq[Text], map_fn: (TextItem) -> TextItem): seq[Text] =
  for line in list:
    var mline: Text
    for item in line:
      mline.add map_fn(item)
    result.add mline

proc map*(paragraphs: seq[Paragraph], map_fn: (TextItem) -> TextItem): seq[Paragraph] =
  for ph in paragraphs:
    result.add:
      case ph.kind
      of ParagraphKind.text:
        var mph = Paragraph(kind: text)
        for item in ph.text:
          mph.text.add map_fn(item)
        mph
      of list:
        Paragraph(kind: list, list: ph.list.map(map_fn))

proc each*(list: seq[Text], fn: (proc (item: TextItem))) =
  for line in list:
    for item in line:
      fn(item)

proc each*(paragraphs: seq[Paragraph], fn: (proc (item: TextItem))) =
  for ph in paragraphs:
      case ph.kind
      of ParagraphKind.text:
        for item in ph.text:
          fn(item)
      of ParagraphKind.list:
        ph.list.each(fn)

var dir_paths_without_extensions_cache: Table[string, Table[string, string]]
proc normalize_asset_path(path: string, warns: var seq[string], doc: Doc): string =
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
    let full_path = asset_path(doc, path)
    if fs.exist full_path:
      path
    else:
      let (dir, name, ext) = fs.split full_path
      if ext.is_empty:
        # Resolving path without extension like 'some_img' to path with extension 'some_img.jpg'
        proc dir_paths_without_extensions: Table[string, string] =
          for entry in fs.read_dir(dir).to_seq.sort.reverse:
            result[entry.path.replace(re"\.[^\.]+", "")] = fs.split(entry.name).ext
        let paths_we = dir_paths_without_extensions_cache.get(dir, dir_paths_without_extensions)
        if full_path in paths_we:
          path & "." & paths_we[full_path]
        else:
          warns.add "Asset doesn't exist: " & path
          path
      else:
        warns.add "Asset doesn't exist: " & path
        path

proc add_text(sentence: var string, text: string) =
  if not sentence.is_empty: sentence.add " "
  sentence.add text

# tags ---------------------------------------------------------------------------------------------
let non_tag_chars = """!@#$%^&*()-=_+{}\|:;,.<>?/""".to_bitset
let tag_delimiter_chars  = space_chars + {','}
let quoted_tag_end_chars = {'\n', '"'}
proc is_tag*(pr: Parser): bool =
  pr.get == '#' and pr.get(1) notin tag_delimiter_chars and pr.get(1) notin non_tag_chars and (pr.get(-1).is_none or pr.get(-1) in tag_delimiter_chars)

proc consume_tag*(pr: Parser): Option[string] =
  assert pr.get == '#'
  pr.inc
  var tag: string
  if pr.get == '"':
    pr.inc
    tag = pr.consume((c) => c notin quoted_tag_end_chars).trim
    if pr.get == '"': pr.inc
  else:
    tag = pr.consume((c) => c notin tag_delimiter_chars and c notin non_tag_chars).trim
  if not tag.is_empty:
    result = tag.some
  else:
    pr.warns.add "Empty tag"

proc consume_tags*(pr: Parser, stop: (proc: bool) = (proc(): bool = false)): tuple[tags: seq[string], line_n: (int, int), pos_n: (int, int)] =
  let i = pr.i
  var unknown = ""; var tags: seq[string];
  pr.skip space_chars
  let tags_start_pos = min(pr.i, pr.text.high)
  while pr.has:
    if stop(): break
    pr.skip((c) => c in tag_delimiter_chars)
    if pr.is_tag:
      let tag = pr.consume_tag
      if tag.is_some: tags.add tag.get
    else:
      if pr.get.is_some: unknown.add pr.get.get
      pr.inc
  if not unknown.is_empty:
    pr.warns.add fmt"Unknown text in tags: {unknown}"
  let tags_end_pos = block:
    let i = pr.rfind(not_space_chars)
    max(tags_start_pos, pr.i - i)
  (tags, (pr.text.line_n(tags_start_pos), pr.text.line_n(tags_end_pos)), (tags_start_pos, tags_end_pos))

# blocks -------------------------------------------------------------------------------------------
let not_tick_chars           = {'^'}.complement
let not_allowed_in_block_ext = {'}'}
let block_id_type_chars      = alphanum_chars + {'.'}

proc has_implicittext(text: string): bool =
  re"\n\s*\n" =~ text

proc parse_block_with_implicittext(text: string): (string, (int, int), string, (int, int)) =
  let split_re {.global.} = re"\n\s*\n"
  let parts = text.reverse.broken_split(split_re, maxsplit = 2)
  assert parts.len == 2, "invalid block with implicittext"
  let (text_blk, blk) = (parts[1].reverse, parts[0].reverse)
  let blk_i = text.findi(re"[^\n\s]", start = text_blk.len)
  assert blk_i > text_blk.len, "internal error, can't get second block start"
  (text_blk, (0, text_blk.high), blk, (blk_i, blk_i + blk.high))

proc consume_block*(pr: Parser, blocks: var seq[FBlockSource], can_have_implicittext: seq[string]) =
  let start = pr.i
  let non_empty_start = pr.i + pr.find(not_space_chars)
  var body = pr.consume(proc (c: auto): bool =
    if c == '^' and (pr.get(1) in alpha_chars):
      for v in pr.items(1): # Looking ahead for newline but not allowing some special characters
        if   v in not_allowed_in_block_ext: return true
        elif v == '\n':                     return false
      return false
    true
  )
  pr.inc
  let id_and_kind = pr.consume block_id_type_chars
  var (id, kind) = if '.' in id_and_kind:
    let parts = id_and_kind.split '.'
    if parts.len > 2: pr.warns.add fmt"Wrong block id or kind: '{id_and_kind}'"
    (parts[0], parts[1])
  else:
    ("", id_and_kind)
  let args = pr.consume (c) => c != '\n'

  if not kind.is_empty:
    # ignoring trailing spaces and newlines to get correct block end line position
    # let prc = pr.deep_copy
    # while prc.i > 0 and prc.get in space_chars: prc.i.dec

    # Processing blocks that have implicit text block before
    kind = kind.trim; body = body.trim
    if kind in can_have_implicittext and body.has_implicittext:
      let (atext, alines, btext, blines) = body.parse_block_with_implicittext

      blocks.add FBlockSource(text: atext.trim, kind: "text", line_n: (
        pr.text.line_n(non_empty_start + alines[0]),
        pr.text.line_n(non_empty_start + alines[1])
      ))

      blocks.add FBlockSource(text: btext.trim, kind: kind.trim, id: id, args: args.trim, line_n: (
        pr.text.line_n(non_empty_start + blines[0]),
        pr.text.line_n(non_empty_start + blines[1])
      ))
    else:
      blocks.add FBlockSource(text: body.trim, kind: kind.trim, id: id, args: args.trim, line_n: (
        pr.text.line_n(non_empty_start),
        pr.text.line_n(non_empty_start + body.trim.len)
      ))
  else:
    pr.i = start # rolling back

proc consume_blocks*(pr: Parser, can_have_implicittext: seq[string]): seq[FBlockSource] =
  var prev_i = -1
  while true:
    pr.consume_block(result, can_have_implicittext)
    if pr.i == prev_i: break
    prev_i = pr.i

# text_embedding -----------------------------------------------------------------------------------
proc is_text_embed*(pr: Parser): bool =
  (pr.get in alpha_chars and pr.fget(not_alpha_chars, limit = lookahead_limit) == '{') or pr.get == '`'

proc consume_text_embed*(pr: Parser, items: var Text) =
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
  items.add TextItem(kind: embed, embed: Embed(kind: kind, body: body))

# find_without_embed -------------------------------------------------------------------------------
proc find_without_embed*(pr: Parser, fn: (char) -> bool): int =
  let i = pr.i
  defer: pr.i = i
  var tmp: Text
  while true:
    if pr.is_text_embed:
      pr.consume_text_embed(tmp)
    else:
      let c = pr.get
      if c.is_none: break
      if fn(c.get): return pr.i - pr.i
    pr.inc
  -1

# text_link ----------------------------------------------------------------------------------------
proc is_text_link*(pr: Parser): bool =
  pr.get == '['

proc is_local_link(link: string): bool =
  # If link is a local or global link
  assert not link.is_empty
  "://" notin link

proc parse_local_link(link: string, pr: Parser): Link =
  let parts = link.split("/").reject(is_empty)
  case parts.len
  of 1:
    (".", parts[0], "")
  of 2:
    (parts[0], parts[1], "")
  of 3:
    (parts[0], parts[1], parts[2])
  else:
    pr.warns.add fmt"Invalid link, too many parts: '{link}'"
    (parts[0], parts[1], parts[2])

let link_chars = {']', ')', '\n'}.complement
proc consume_text_link*(pr: Parser, items: var Text) =
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
      let link = parse_local_link(link, pr)
      items.add TextItem(kind: TextItemKind.link, text: name, link: link)
    else:
      items.add TextItem(kind: TextItemKind.glink, text: name, glink: link)
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
proc consume_inline_text*(pr: Parser, stop: (proc: bool), trim = false): Text =
  var text = ""; var em_started_i: int = -1

  template finish_text =
    text = text.replace(re"[\s\n]+", " ")
    if trim: text = text.trim
    if not text.is_empty:
      result.add TextItem(kind: TextItemKind.text, text: text)
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
      if tag.is_some: result.add TextItem(kind: TextItemKind.tag, text: tag.get)
    else:
      text.add pr.get.get
      pr.inc

  finish_text()

  # Removing trailing space from last element or whole element if it's empty
  if (not result.is_empty) and result.last.kind == TextItemKind.text:
    result[^1].text = result[^1].text.strip(leading = false, trailing = true)
    if result.last.text.is_empty: discard result.pop

proc consume_inline_text*(text: string): Text =
  let pr = Parser.init(text)
  result = pr.consume_inline_text(() => false)
  assert pr.warns.is_empty, "parsing ftext, unexpected warnings"

# text_paragraph -----------------------------------------------------------------------------------
let st_chars = {' ', '\t'}; let not_st_chars = st_chars.complement
proc is_text_paragraph*(pr: Parser): bool =
  pr.get == '\n' and pr.fget(not_st_chars, 1, limit = lookahead_limit) == '\n'

proc skip_text_paragraph*(pr: Parser) =
  assert pr.is_text_paragraph
  pr.skip {'\n'}
  pr.skip st_chars
  pr.skip {'\n'}

# text_list ----------------------------------------------------------------------------------------
proc is_text_list*(pr: Parser): bool =
  (pr.i == 0 or pr.is_text_paragraph) and pr.fget(not_space_chars, limit = lookahead_limit) == '-'

proc is_text_list_item*(pr: Parser): bool =
  (pr.i == 0 or pr.get == '\n') and pr.fget(not_space_chars, limit = lookahead_limit) == '-'

proc consume_list_item*(pr: Parser): Text =
  pr.skip space_chars
  assert pr.get == '-'
  pr.inc
  pr.skip space_chars
  proc stop: bool = pr.is_text_paragraph or pr.is_text_list or pr.is_text_list_item
  pr.consume_inline_text(stop)

proc consume_text_list*(pr: Parser): seq[Text] =
  while pr.is_text_list_item:
    let inline_text = pr.consume_list_item
    if not inline_text.is_empty:
      result.add inline_text

# text ---------------------------------------------------------------------------------------------
proc parse_text_as_items*(pr: Parser): seq[Paragraph] =
  var paragraph: Text

  template finish_paragraph =
    if not paragraph.is_empty:
      result.add Paragraph(kind: ParagraphKind.text, text: paragraph)
      paragraph = Text.init

  proc stop: bool = pr.is_text_paragraph or pr.is_text_list

  while pr.has:
    if   pr.is_text_list:
      let items = pr.consume_text_list
      if not items.is_empty:
        result.add Paragraph(kind: list, list: items)
    elif pr.is_text_paragraph:
      pr.skip_text_paragraph
      pr.skip space_chars
    else:
      let inline_text = pr.consume_inline_text(stop)
      if not inline_text.is_empty:
        result.add Paragraph(kind: ParagraphKind.text, text: inline_text)

proc link_to_text(link: Link): string =
  result = if link[0] == ".": link[1] else: link[0] & "/" & link[1]
  unless link[2].is_empty: result.add " " & link[2]

proc add_text_item_data(blk: Block, item: TextItem): void =
  case item.kind
  of TextItemKind.text:
    blk.text.add_text item.text
  of link:
    blk.links.add item.link
    blk.text.add_text item.text
    blk.text.add_text item.link.link_to_text
  of glink:
    blk.glinks.add item.glink
    blk.text.add_text item.text
    blk.text.add_text item.glink
  of tag:
    blk.tags.add item.text
    blk.text.add_text item.text
  of embed:
    discard

proc post_process*(item: TextItem, blk: Block, doc: Doc, config: FParseConfig): TextItem =
  var item = item
  blk.add_text_item_data item # Extracting text
  if item.kind == embed: # Post processing embed items
    let (kind, body) = (item.embed.kind, item.embed.body)
    if kind in config.embed_parsers:
      let eparser: FEmbedParser = config.embed_parsers[kind]
      item.embed = eparser(body, blk, doc, config)
      item.embed.kind = kind; item.embed.body = body
    else:
      blk.warns.add fmt"Unknown embed: " & kind
  item

proc args_should_be_empty(source: FBlockSource, warns: var seq[string]) =
  unless source.args.is_empty:
    warns.add "Unknown args: " & source.args

proc parse_text*(source: FBlockSource, doc: Doc, config: FParseConfig): TextBlock =
  assert source.kind == "text"
  let pr = Parser.init source.text
  let ftext = pr.parse_text_as_items
  let blk = TextBlock(warns: pr.warns)
  source.args_should_be_empty blk.warns
  proc post_process(item: TextItem): TextItem = post_process(item, blk, doc, config)
  blk.ftext = map(ftext, post_process)
  blk

proc parse_embed_image*(path: string, blk: Block, doc: Doc): ImageEmbed =
  let path = normalize_asset_path(path, blk.warns, doc)
  unless path.is_empty: blk.assets.add path
  blk.text.add_text path
  ImageEmbed(path: path)

proc parse_embed_code*(code: string, blk: Block): CodeEmbed =
  blk.text.add_text code
  CodeEmbed(code: code)

# list ---------------------------------------------------------------------------------------------
proc parse_tags_on_last_line_if_present(raw: string, not_tags: (proc(lines: seq[string]): bool), blk: Block): string =
  var lines = raw.trim.split("\n")
  if lines.len > 0:
    # let starts_with_tag_character = lpr.find_without_embed((c) => c == '#') >= 0
    let starts_with_tag_character = lines.last.trim.starts_with("#")
    if starts_with_tag_character and not not_tags(lines):
      let lpr = Parser.init(lines.last.trim)
      let tags = lpr.consume_tags.tags
      blk.tags.add tags
      blk.warns.add lpr.warns
      lines.len = lines.len - 1
      return lines.join("\n").trim
  raw

proc parse_list_as_items*(raw: string, blk: ListBlock) =
  let pr = Parser.init raw
  if pr.fget(not_space_chars, limit = lookahead_limit) == '-': # List imems start with '-' character
    proc not_tags(lines: seq[string]): bool =
      lines.last.trim.starts_with('-')
    let raw_without_tags = parse_tags_on_last_line_if_present(raw, not_tags, blk)
    let pr = Parser.init raw_without_tags
    blk.list = pr.consume_text_list
    pr.skip space_chars
    if pr.has:
      blk.warns.add "Unknown content in list: '" & pr.remainder & "'"
  else: # List imems start with new paragraph
    proc not_tags(lines: seq[string]): bool =
      # Should be separated with new line
      lines.len > 2 and lines[^2].trim != ""
    let raw_without_tags = parse_tags_on_last_line_if_present(raw, not_tags, blk)
    let pr = Parser.init raw_without_tags
    while pr.has:
      let inline_text = pr.consume_inline_text(() => pr.is_text_paragraph)
      if not inline_text.is_empty:
        blk.list.add inline_text
      elif pr.is_text_paragraph:
        pr.skip_text_paragraph
        pr.skip space_chars
      else:
        blk.warns.add "Unknown content in list: '" & pr.remainder & "'"
        break

proc check_keys_in(data: JsonNode, keys: openarray[string], warns: var seq[string]) =
  for k in data.keys:
    if k notin keys: warns.add "Invalid arg: " & k

proc parse_list*(source: FBlockSource, doc: Doc, config: FParseConfig): ListBlock =
  assert source.kind == "list"
  let blk = ListBlock()

  unless source.args.is_empty: # parsing args
    try:
      let data = parse_yaml source.args
      data.check_keys_in(["ph"], blk.warns)
      if "ph" in data: blk.ph = data["ph"].get_bool
    except:
      blk.warns.add "Invalid args"

  parse_list_as_items(source.text, blk)
  proc post_process(item: TextItem): TextItem = post_process(item, blk, doc, config)
  blk.list = map(blk.list, post_process)
  blk

# data ---------------------------------------------------------------------------------------------
proc parse_data*(source: FBlockSource): DataBlock =
  assert source.kind == "data"
  let json = parse_yaml source.text
  let blk = DataBlock(data: json, text: source.text)
  source.args_should_be_empty blk.warns
  blk

# section ------------------------------------------------------------------------------------------
proc parse_section[T](source: FBlockSource, section: T) =
  let pr = Parser.init source.text; let kind: string = source.kind
  let ftext = pr.consume_inline_text () => false
  if pr.has_next: section.warns.add fmt"Invalid text in {kind}: '{pr.remainder}'"
  var texts: seq[string]
  for item in ftext:
    case item.kind
    of TextItemKind.text:
      texts.add item.text
    of tag:
      section.tags.add item.text
    else:
      section.warns.add fmt"Invalid text in {kind} : '{pr.remainder}'"
  section.title = texts.join " "
  if section.title.is_empty: section.warns.add fmt"Empty {kind} title"

proc parse_section*(source: FBlockSource): SectionBlock =
  assert source.kind == "section"
  let blk = SectionBlock()
  source.args_should_be_empty blk.warns
  parse_section(source, blk)
  blk

proc parse_subsection*(source: FBlockSource): SubsectionBlock =
  assert source.kind == "subsection"
  let blk = SubsectionBlock()
  source.args_should_be_empty blk.warns
  parse_section(source, blk)
  unless blk.tags.is_empty: result.warns.add "tags not supported for subsection"
  blk

# title --------------------------------------------------------------------------------------------
proc parse_title*(source: FBlockSource): string =
  assert source.kind == "title"
  assert source.args == ""
  source.text

# proc extract_title_from_location(location: string): string =
#   location.split("/").last.replace(re"\.[a-zA-Z0-9]+", "")

# code ---------------------------------------------------------------------------------------------
proc parse_code*(source: FBlockSource): CodeBlock =
  assert source.kind == "code"
  let blk = CodeBlock(code: source.text.trim, text: source.text.trim)
  source.args_should_be_empty blk.warns
  blk

# image, images ------------------------------------------------------------------------------------
proc parse_path_and_tags(text: string, warns: var seq[string], doc: Doc): tuple[path: string, tags: seq[string]] =
  let parts = text.split("#", maxsplit = 1)
  var path = parts[0].trim; var tags: seq[string]
  path = normalize_asset_path(path, warns, doc)
  if parts.len > 1:
    let pr = Parser.init("#" & parts[1])
    tags = pr.consume_tags.tags
    if pr.has:
      warns.add "Unknown content in image: '" & pr.remainder & "'"
  (path, tags)

proc parse_image*(source: FBlockSource, doc: Doc): ImageBlock =
  var warns: seq[string]
  let (path, tags) = parse_path_and_tags(source.text, warns, doc)
  var assets: seq[string]
  unless path.is_empty: assets.add path
  let blk = ImageBlock(image: path, tags: tags, warns: warns, text: source.text, assets: assets)
  source.args_should_be_empty blk.warns
  blk

proc parse_images*(source: FBlockSource, doc: Doc): ImagesBlock =
  assert source.kind == "images"
  var warns: seq[string]
  let (path, tags) = parse_path_and_tags(source.text, warns, doc)
  let blk = ImagesBlock(images_dir: path, tags: tags, warns: warns, text: source.text)

  unless source.args.is_empty: # parsing args
    try:
      let data = parse_yaml source.args
      data.check_keys_in(["cols"], blk.warns)
      if "cols" in data: data["cols"].json_to blk.cols # blk.cols = data["cols"].get_int.some
    except:
      blk.warns.add "Invalid args"

  unless path.is_empty:
    blk.assets = @[path]
    let images_path = asset_path(doc, path)
    proc normalize_asset_path(fname: string): string =
      if path == ".": fname else: path & "/" & fname
    blk.images = fs.read_dir(images_path)
      .filter((entry) => entry.kind == file).pick(name).map(normalize_asset_path).sort
    blk.assets.add blk.images
  blk

# table --------------------------------------------------------------------------------------------
proc parse_table_as_table(pr: Parser, col_delimiter: char, has_header: bool, blk: TableBlock) =
  let is_row_delimiter = block:
    let pr = pr.deep_copy
    # Default delimiter is newline, but if there's double newline happens anywhere in table text, then
    # the double newline used as delimiter.
    pr.skip space_chars
    proc is_double_newline: bool = pr.get == '\n' and pr.get(1) == '\n'
    discard pr.consume_inline_text(is_double_newline) # need to skip text embed that may have newlines
    if is_double_newline():
      proc(pr: Parser): bool = pr.get == '\n' and pr.get(1) == '\n'
    else:
      proc(pr: Parser): bool = pr.get == '\n'

  # proc is_header(): bool =
  #   pr.starts_with("header") and (pr.get(6) == '\n' or pr.get(6).is_none)

  proc stop(): bool =
    pr.get in {col_delimiter, ':'} or pr.is_row_delimiter() #or is_header()

  var row = seq[Text].init; var is_first_row = true
  var first_row = true
  template finish_row() =
    row.add token
    if not row.is_empty:
      if first_row and has_header:
        blk.header = row.some
        first_row = false
      else:
        blk.rows.add row
      row = seq[Text].init
    is_first_row = false

  while pr.has:
    pr.skip space_chars
    let token = pr.consume_inline_text(stop)
    # if   is_header(): # header
    #   finish_row:
    #     blk.header = row.some
    #   pr.skip "header".to_bitset
    if pr.is_row_delimiter(): # row delimiter
      finish_row()
    elif pr.get == col_delimiter: # column delimiter
      row.add token
    else:
      finish_row()
      if pr.has: pr.warns.add "Unknown content in table: '" & pr.remainder & "'"
      break
    pr.inc
  blk.warns.add pr.warns

proc parse_table*(source: FBlockSource, doc: Doc, config: FParseConfig): TableBlock =
  assert source.kind == "table"
  let blk = TableBlock()

  var has_header = false
  unless source.args.is_empty: # parsing args
    try:
      let data = parse_yaml "{ " & source.args & " }"
      data.check_keys_in(["style", "header", "card_cols"], blk.warns)
      if "style"     in data: data["style"].json_to blk.style
      if "header"    in data: data["header"].json_to has_header
      if "card_cols" in data: data["card_cols"].json_to blk.card_cols
    except:
      blk.warns.add "Invalid args"

  let col_delimiter: char = block:
    let pr = Parser.init source.text
    if pr.find_without_embed((c) => c == '|') >= 0: '|' else: ','

  proc not_tags(lines: seq[string]): bool =
    # If last line has tag character and don't have col delimiter character and is not a continuation
    # of the table row
    let last_line_has_col_delimiter = Parser.init(lines.last)
      .find_without_embed((c) => c == col_delimiter) >= 0
    let before_last_line_ending_with_col_delimiter = lines.len > 1 and
      lines[^2].trim.ends_with(col_delimiter)
    last_line_has_col_delimiter or before_last_line_ending_with_col_delimiter

  let text_without_tags = parse_tags_on_last_line_if_present(source.text, not_tags, blk)

  let pr = Parser.init(text_without_tags)
  pr.parse_table_as_table(col_delimiter, has_header, blk)

  block: # normalizing cols count
    var cols = 0
    if blk.header.is_some:
      cols = blk.header.get.len
    else:
      for row in blk.rows:
        if row.len > cols: cols = row.len
    for i, row in blk.rows:
      if row.len > cols:
        blk.warns.add "Too many cols in row"
        blk.rows[i].len = cols
      elif row.len < cols:
        blk.warns.add "Missing cols in row"
        while blk.rows[i].len < cols: blk.rows[i].add @[]
    blk.cols = cols

  proc post_process(item: TextItem): TextItem = post_process(item, blk, doc, config)
  if blk.header.is_some: blk.header = map(blk.header.get, post_process).some
  for i, row in blk.rows: blk.rows[i] = map(row, post_process)
  blk

# FParseConfig --------------------------------------------------------------------------------------
proc init*(_: type[FParseConfig]): FParseConfig =
  var block_parsers: Table[string, FBlockParser]
  block_parsers["text"]   = (blk, doc, config) => parse_text(blk, doc, config)
  block_parsers["list"]   = (blk, doc, config) => parse_list(blk, doc, config)
  block_parsers["data"]   = (blk, doc, config) => parse_data(blk)
  block_parsers["code"]   = (blk, doc, config) => parse_code(blk)
  block_parsers["image"]  = (blk, doc, config) => parse_image(blk, doc)
  block_parsers["img"] = block_parsers["image"]
  block_parsers["images"] = (blk, doc, config) => parse_images(blk, doc)
  block_parsers["table"]  = (blk, doc, config) => parse_table(blk, doc, config)

  block_parsers["section"]    = (blk, doc, config) => parse_section(blk)
  block_parsers["subsection"] = (blk, doc, config) => parse_subsection(blk)

  var embed_parsers: Table[string, FEmbedParser]
  embed_parsers["image"] = (raw, blk, doc, config) => parse_embed_image(raw, blk, doc).Embed
  embed_parsers["img"] = embed_parsers["image"]
  embed_parsers["code"]  = (raw, blk, doc, config) => parse_embed_code(raw, blk).Embed

  let can_have_implicittext = @["image", "images", "section", "subsection"]

  FParseConfig(block_parsers: block_parsers, embed_parsers: embed_parsers,
    can_have_implicittext: can_have_implicittext)

# consume_doc_tags ---------------------------------------------------------------------------------
proc consume_doc_tags*(pr: Parser): tuple[blk: Option[FBlockSource], tags: seq[string], line_n: (int, int)] =
  # Doc tags may have implicittext
  pr.skip space_chars
  let tags_text = pr.remainder
  if pr.find_without_embed((_) => pr.is_tag) < 0 and pr.find_without_embed((c) => c notin space_chars) >= 0:
    # No tags only text block
    let text = pr.remainder.trim
    let blk = FBlockSource(text: text, kind: "text", line_n: (
      pr.text.line_n(pr.i),
      pr.text.line_n(pr.i + text.high)
    ))
    (blk.some, @[], (-1, -1))
  elif tags_text.has_implicittext:
    let (atext, alines, btext, blines) = tags_text.parse_block_with_implicittext

    let blk = FBlockSource(text: atext.trim, kind: "text", line_n: (
      pr.text.line_n(pr.i + alines[0]),
      pr.text.line_n(pr.i + alines[1])
    ))

    let tpr = Parser.init btext
    let (tags, _, tags_pos_n) = tpr.consume_tags
    pr.warns.add tpr.warns

    (blk.some, tags, (
      pr.text.line_n(pr.i + tags_pos_n[0] + blines[0]),
      pr.text.line_n(pr.i + tags_pos_n[1] + blines[1])
    ))
  else:
    let (tags, lines, _) = pr.consume_tags
    (FBlockSource.none, tags, lines)

# parse --------------------------------------------------------------------------------------------
proc post_process_block(blk: Block, doc: Doc, config: FParseConfig) =
  template normalize(term) = blk.term = blk.term.unique.sort
  normalize assets
  normalize links
  normalize glinks
  normalize warns
  normalize tags

  # for rpath in blk.assets:
  #   assert not rpath.is_empty, "asset can't be empty"
  #   unless fs.exist(asset_path(doc, rpath)):
  #     blk.warns.add fmt"Asset don't exist {doc.id}/{rpath}"

proc init_fdoc*(location: string): Doc =
  assert location.ends_with ".ft"
  let id = location.file_name.file_name_ext.name
  Doc(id: id, asset_path: location[0..^4].some)

proc parse*(_: type[Doc], text, location: string, config = FParseConfig.init): Doc =
  let pr = Parser.init(text)
  var source_blocks = pr.consume_blocks(config.can_have_implicittext)
  let (blk, tags, tags_line_n) = pr.consume_doc_tags
  if blk.is_some: source_blocks.add blk.get

  let doc = init_fdoc location
  doc.warns.add pr.warns
  let doc_source = DocTextSource(kind: "ftext", location: location, tags_line_n: tags_line_n)
  doc.hash = text.hash.int; doc.tags = tags; doc.source = doc_source
  for source in source_blocks:
    if   source.kind == "title":
      doc.title = parse_title source
    # elif source.kind == "section":
    #   let section = parse_section source
    #   doc.sections.add section
    else:
      # if doc.sections.is_empty:
      #   let source = FBlockSource(line_n: (-1, -1))
      #   doc.sections.add Section(source: source)
      # doc.sections[^1].blocks.add:
      let blk = if source.kind in config.block_parsers:
        config.block_parsers[source.kind](source, doc, config)
      else:
        doc.warns.add fmt"Unknown block kind '{source.kind}'"
        UnknownBlock()
      blk.id = source.id; blk.hash = source.text.hash.int; blk.source = source
      post_process_block(blk, doc, config)
      doc.blocks.add blk
  doc.blockids = doc.blocks.filterit(not it.id.is_empty).to_table((b) => b.id)
  doc

proc read*(_: type[Doc], location: string, config = FParseConfig.init): Doc =
  Doc.parse(text = fs.read(location), location = location, config = config)