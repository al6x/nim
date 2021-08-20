import ./supportm, ./optionm, strutils, sugar, sequtils, strformat, tables
from std/nre as nre import nil
from std/options as stdoptions import nil

type Regex* = nre.Regex


proc re*(s: string): Regex = nre.re(s)


proc match*(s: string, r: Regex): bool = nre.contains(s, r)

test "match":
  assert "abc".match(re"b")
  assert "abc".match(re"abc")
  assert "abc".match(re"^abc$")
  assert not "abc".match(re"d")

  assert "abc".match(re"(?i)B") # case insensitive


proc `=~`*(s: string, r: Regex): bool = match(s, r)
proc `!~`*(s: string, r: Regex): bool = not(s =~ r)

proc `=~`*(r: Regex, s: string): bool = s =~ r
proc `!~`*(r: Regex, s: string): bool = s !~ r



proc split*(s: string, r: Regex): seq[string] = nre.split(s, r)

test "split":
  assert "abcde".split(re"[bcd]+") == @["a", "e"]



proc replace*(s: string, r: Regex, by: string): string = nre.replace(s, r, by)

proc replace*(s: string, r: Regex, by: (proc (match: string): string)): string = nre.replace(s, r, by)

test "replace":
  assert "abcde".replace(re"[bcd]", "_") == "a___e"
  assert "abcde".replace(re"[bcd]", (match) => match.to_upper) == "aBCDe"



proc find*(s: string, r: Regex): Option[string] =
  let found = nre.find(s, r)
  if stdoptions.is_some(found): nre.match(stdoptions.get(found)).some else: return

test "find":
  assert "abcde".find(re"[bcd]") == "b".some
  assert "abcde".find(re"[x]").is_none



proc parse*(r: Regex, s: string): Option[seq[string]] =
  let found = nre.match(s, r)
  if stdoptions.is_some(found):
    let captures = to_seq(nre.items(nre.captures(stdoptions.get(found)))).map((o) => stdoptions.get(o))
    if captures.len > 0:
      return captures.some

test "parse":
  assert re".+ (\d+) (\d+)".parse("a 22 45") == @["22", "45"].some
  assert re"[^;]+;".parse("drop table; create table;").is_none



proc parse_named*(r: Regex, s: string): Table[string, string] =
  let found = nre.match(s, r)
  if stdoptions.is_some(found):
    nre.to_table(nre.captures(stdoptions.get(found)))
  else:
    return

test "parse_named":
  assert re".+ (?<a>\d+) (?<b>\d+)".parse_named("a 22 45") == { "a": "22", "b": "45" }.to_table


iterator find_iter*(s: string, r: Regex): string =
  for match in nre.find_iter(s, r): yield nre.match(match)

test "find_iter":
  assert to_seq("abcde".find_iter(re"[bcd]")) == @["b", "c", "d"]


proc find_all*(s: string, r: Regex): seq[string] = to_seq(find_iter(s, r))

test "find_all":
  assert "abcde".find_all(re"[bcd]") == @["b", "c", "d"]
  assert "abcde".find_all(re"[x]") == @[]


proc parse1*(r: Regex, s: string): string =
  let parts = r.parse(s).get
  if parts.len != 1: throw fmt"expected 1 match but found {parts.len}"
  parts[0]

proc parse2*(r: Regex, s: string): (string, string) =
  let parts = r.parse(s).get
  if parts.len != 2: throw fmt"expected 2 match but found {parts.len}"
  (parts[0], parts[1])

proc parse3*(r: Regex, s: string): (string, string, string) =
  let parts = r.parse(s).get
  if parts.len != 3: throw fmt"expected 3 matches but found {parts.len}"
  (parts[0], parts[1], parts[2])

proc parse4*(r: Regex, s: string): (string, string, string, string) =
  let parts = r.parse(s).get
  if parts.len != 4: throw fmt"expected 4 matches but found {parts.len}"
  (parts[0], parts[1], parts[2], parts[3])

proc parse5*(r: Regex, s: string): (string, string, string, string, string) =
  let parts = r.parse(s).get
  if parts.len != 5: throw fmt"expected 5 matches but found {parts.len}"
  (parts[0], parts[1], parts[2], parts[3], parts[4])

test "parse1,2,3,4,5":
  let pattern = re".+ (\d+) (\d+)"
  assert pattern.parse2("a 22 45") == ("22", "45")