import base, ext/parser

type Filter* = object
  incl*, excl*: seq[string] # tags, sorted, unique
  query*:       string

proc init*(_: type[Filter], incl = seq[string].init, excl = seq[string].init, query = ""): Filter =
  Filter(incl: incl.unique.sort, excl: excl.unique.sort, query: query)

proc is_tag(pr: Parser): bool =
  (
    (pr.get == '#' and pr.get(1) != ' ') or
    (pr.get == '-' and pr.get(1) == '#' and pr.get(2) != ' ')
  ) and (pr.get(-1).is_none or pr.get(-1) == ' ')

proc parse*(_: type[Filter], s: string): Filter =
  var incl, excl: seq[string]; var query: string
  let pr = Parser.init s
  while pr.has:
    if pr.is_tag:
      var exclude = false
      if pr.get == '-':
        pr.inc
        exclude = true
      assert pr.get == '#'
      pr.inc
      let tag = pr.consume((c) => c != ' ').replace('-', ' ')
      unless tag.is_empty:
        if exclude: excl.add tag
        else:       incl.add tag
      pr.skip((c) => c == ' ')
    else:
      query.add pr.get.get # = pr.consume((c) => true)
      pr.inc
  Filter.init(incl = incl, excl = excl, query = query.trim)

proc `$`*(f: Filter): string =
  template add(s: string) =
    unless s.is_empty:
      unless result.is_empty: result.add " "
      result.add s

  template decode(tag: string): string =
    "#" & tag.replace(' ', '-').to_lower

  add f.incl.mapit(decode(it)).sort.join(" ")
  add f.excl.mapit("-" & decode(it)).sort.join(" ")
  add f.query

test "filter to_s, parse":
  let f = Filter.init(incl = @["t1", "t 2"], excl = @["t3"], query = "some text")
  check f.to_s == "#t-2 #t1 -#t3 some text"
  check f == Filter.parse(f.to_s)

test "filter parse":
  let f = Filter.parse("#t some #t2 text #t3")
  check (f.incl, f.excl, f.query) == (@["t3", "t", "t2"], seq[string].init, "some text")