import std/[strutils, sugar, sequtils, strformat, tables]
from std/nre as nre import nil
from std/options as stdoptions import nil
import ./test, ./option

template throw(message: string) = raise Exception.new_exception(message)

type Regex* = nre.Regex

proc re*(s: string): Regex =
  nre.re(s)

proc match*(s: string, r: Regex): bool =
  nre.contains(s, r)

test "match":
  check:
    "abc".match(re"b")
    "abc".match(re"abc")
    "abc".match(re"^abc$")
    not "abc".match(re"d")
    "abc".match(re"(?i)B") # case insensitive


proc `=~`*(s: string, r: Regex): bool = match(s, r)
proc `!~`*(s: string, r: Regex): bool = not(s =~ r)

proc `=~`*(r: Regex, s: string): bool = s =~ r
proc `!~`*(r: Regex, s: string): bool = s !~ r



proc split*(s: string, r: Regex): seq[string] = nre.split(s, r)

proc broken_split*(s: string, r: Regex, maxsplit = -1): seq[string] = nre.split(s, r, max_split = maxsplit)

test "split":
  check "abcde".split(re"[bcd]+") == @["a", "e"]



proc replace*(s: string, r: Regex, by: string): string = nre.replace(s, r, by)

proc replace*(s: string, r: Regex, by: (proc (match: string): string)): string =
  nre.replace(s, r, proc (nre_match: nre.RegexMatch): string =
    let captures = nre.captures(nre_match)
    by(nre.`[]`(captures, 0))
  )

proc replace*(s: string, r: Regex, by: (proc (match1, match2: string): string)): string =
  nre.replace(s, r, proc (nre_match: nre.RegexMatch): string =
    let captures = nre.captures(nre_match)
    by(nre.`[]`(captures, 0), nre.`[]`(captures, 1))
  )

# proc mreplace_multiple*(s: string, r: Regex, by: (proc (matches: seq[string]): string)): string =
#   nre.replace(s, r, proc (nre_match: nre.RegexMatch): string =
#     by(to_seq(nre.items(nre.captures(nre_match))).map((match) => match.get))
#   )

test "replace":
  check:
    "abcd".replace(re"[bc]", "_") == "a__d"
    "abcd".replace(re"a([bc]+)", (match) => match.to_upper) == "BCd"
    "abcde".replace(re"a(.)c(.)", (m1, m2) => @[m1, m2].map(to_upper).join("")) == "BDe"



proc find*(s: string, r: Regex, start = 0): Option[string] =
  let found = nre.find(s, r, start)
  if stdoptions.is_some(found): nre.match(stdoptions.get(found)).some else: return

test "find":
  check:
    "abcde".find(re"[bcd]") == "b".some
    "abcde".find(re"[x]").is_none


proc findi*(s: string, r: Regex, start = 0): int =
  let found = nre.find(s, r, start)
  if stdoptions.is_some(found): nre.match_bounds(stdoptions.get(found)).a else: -1

test "findi":
  check: "abcde".findi(re"[bcd]") == 1

proc parse*(r: Regex, s: string): Option[seq[string]] =
  let found = nre.match(s, r)
  if stdoptions.is_some(found):
    let captures = to_seq(nre.items(nre.captures(stdoptions.get(found)))).map((o) => stdoptions.get(o))
    if captures.len > 0:
      return captures.some

test "parse":
  check:
    re".+ (\d+) (\d+)".parse("a 22 45") == @["22", "45"].some
    re"[^;]+;".parse("drop table; create table;").is_none



proc parse_named*(r: Regex, s: string): Table[string, string] =
  let found = nre.match(s, r)
  if stdoptions.is_some(found):
    nre.to_table(nre.captures(stdoptions.get(found)))
  else:
    return

test "parse_named":
  check re".+ (?<a>\d+) (?<b>\d+)".parse_named("a 22 45") == { "a": "22", "b": "45" }.to_table


iterator find_iter*(s: string, r: Regex): string =
  for match in nre.find_iter(s, r):
    yield nre.match(match)

test "find_iter":
  check to_seq("abcde".find_iter(re"[bcd]")) == @["b", "c", "d"]

proc find_all*(s: string, r: Regex): seq[HSlice[int, int]] =
  for match in nre.find_iter(s, r):
    result.add nre.match_bounds(match)

test "find_all":
  check:
    "abcde".find_all(re"[bcd]") == @[1..1, 2..2, 3..3]
    "abcde".find_all(re"[x]").len == 0

proc get_all*(s: string, r: Regex): seq[string] =
  to_seq(find_iter(s, r))

test "get_all":
  check:
    "abcde".get_all(re"[bcd]") == @["b", "c", "d"]
    "abcde".get_all(re"[x]").len == 0


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
  check pattern.parse2("a 22 45") == ("22", "45")