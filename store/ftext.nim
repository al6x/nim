import base, std/os

type Warning = tuple[message: string, data: JsonNode]

type Info* = ref object of RootObj
  t location*: string
  t parent*:   Info
  text*:     string
  tags*:     seq[string]

type Doc* = ref object of Info
  infos: seq[Info]

proc parse_ftext*(text: string) =
  var warnings: seq[Warning]

  # Splitting into body and tags
  let (body_text, tags_text) = block:
    let parts = re"(?si)(.*)\n[\s\n]*(#[#a-z0-9_\-\s]+)".parse(text)
    if   parts.is_none:
      (text, "")
    else:
      (parts.get[0], parts.get[1])

  # Splitting body into infos
  let infos: seq[(string, string)] = block:
    let parse_block_re = re"(?si)^(.+? )\^([a-z][a-z0-9_\-]*)$"
    body_text
      .find_all(re"(?si).+? \^[a-z][a-z0-9_-]*(\n|\Z)")
      .map(trim)
      .map((text) => parse_block_re.parse2(text))

  # Parsing tags
  let tags: seq[string] = tags_text
    .find_all(re"#[a-z0-9_\-]+\s*")
    .map(trim)
    .map((tag) => tag.replace("#", ""))

  p infos
  p tags

#   p blocks
#   # echo blocks
#   # some text ^list

slow_test "parse_ftext without tags":
  check """
    some text ^text
  """.dedent.parse_ftext == ""

slow_test "parse_ftext":
  let dirname = current_source_path().parent_dir
  let basics = fs.read dirname & "/ftext/basics.ft"
  parse_ftext(basics)

  # test with tags and without tags