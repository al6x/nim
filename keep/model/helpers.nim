import base, ext/parser, ./docm

# Embed.to_json ------------------------------------------------------------------------------------
method to_json_hook_method*(embed: Embed): JsonNode {.base.} = %{}
method to_json_hook_method*(embed: ImageEmbed): JsonNode     = embed.to_json
method to_json_hook_method*(embed: CodeEmbed): JsonNode      = embed.to_json
proc   to_json_hook*(embed: Embed): JsonNode                 = embed.to_json_hook_method

# Filter -------------------------------------------------------------------------------------------
proc is_tag(pr: Parser): bool =
  (
    (pr.get == '#' and pr.get(1) != ' ') or
    (pr.get == '-' and pr.get(1) == '#' and pr.get(2) != ' ')
  ) and (pr.get(-1).is_none or pr.get(-1) == ' ')

proc parse*(_: type[Filter], s: string): Filter =
  var incl, excl: seq[int]; var query: string
  let pr = Parser.init s
  while pr.has:
    pr.skip((c) => c == ' ')
    if pr.is_tag:
      var exclude = false
      if pr.get == '-':
        pr.inc
        exclude = true
      assert pr.get == '#'
      pr.inc
      let tag = pr.consume((c) => c != ' ').replace('-', ' ')
      unless tag.is_empty:
        if exclude: excl.add tag.encode_tag
        else:       incl.add tag.encode_tag
    else:
      query = pr.consume((c) => true)
  Filter.init(incl = incl, excl = excl, query = query)

proc `$`*(f: Filter): string =
  template add(s: string) =
    unless s.is_empty:
      unless result.is_empty: result.add " "
      result.add s

  template decode(tag: int): string =
    "#" & tag.decode_tag.replace(' ', '-').to_lower

  add f.incl.mapit(decode(it)).sort.join(" ")
  add f.excl.mapit("-" & decode(it)).sort.join(" ")
  add f.query

test "parse":
  let f = Filter.init(incl = @["t1", "t 2"].map(encode_tag), excl = @["t3"].map(encode_tag), query = "some text")
  check f.to_s == "#t1 #t-2 -#t3 some text"
  check f == Filter.parse(f.to_s)