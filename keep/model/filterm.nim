import base, ext/parser, ./docm

type Filter* = object
  incl*: seq[int]
  excl*: seq[int]
  text*: string

proc init*(_: type[Filter], incl: seq[int] = @[], excl: seq[int] = @[], text = ""): Filter =
  Filter(incl: incl.unique.sort, excl: excl.unique.sort, text: text)

proc `$`*(f: Filter): string =
  template add(s: string) =
    unless s.is_empty:
      unless result.is_empty: result.add " "
      result.add s

  template encode(tag: int): string =
    "#" & tag.decode_tag.replace(' ', '-')

  add f.incl.mapit(encode(it)).join(" ")
  add f.excl.mapit("-" & encode(it)).join(" ")
  add f.text

proc is_tag(pr: Parser): bool =
  (
    (pr.get == '#' and pr.get(1) != ' ') or
    (pr.get == '-' and pr.get(1) == '#' and pr.get(2) != ' ')
  ) and (pr.get(-1).is_none or pr.get(-1) == ' ')

proc parse*(_: type[Filter], s: string): Filter =
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
      assert not tag.is_empty
      if exclude: result.excl.add tag.encode_tag
      else:       result.incl.add tag.encode_tag
    else:
      result.text = pr.consume((c) => true)

test "parse":
  let f = Filter.init(incl = @["t1", "t 2"].map(encode_tag), excl = @["t3"].map(encode_tag), text = "some text")
  check f.to_s == "#t1 #t-2 -#t3 some text"
  check f == Filter.parse(f.to_s)