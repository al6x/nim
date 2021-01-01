import ./supportm, options, strutils, sugar, sequtils, strformat
from std/nre as nre import nil

type Regex* = nre.Regex

# re -----------------------------------------------------------------------------------------------
proc re*(s: string): Regex = nre.re(s)

# match --------------------------------------------------------------------------------------------
proc match*(s: string, r: Regex): bool = nre.contains(s, r)

test "match":
  assert "abc".match(re"b")
  assert "abc".match(re"abc")
  assert "abc".match(re"^abc$")
  assert not "abc".match(re"d")

  assert "abc".match(re"(?i)B")

# =~ and != ----------------------------------------------------------------------------------------
proc `=~`*(s: string, r: Regex): bool = match(s, r)
proc `!~`*(s: string, r: Regex): bool = not(s =~ r)

proc `=~`*(r: Regex, s: string): bool = s =~ r
proc `!~`*(r: Regex, s: string): bool = s !~ r


# split --------------------------------------------------------------------------------------------
proc split*(s: string, r: Regex): seq[string] = nre.split(s, r)

test "split":
  assert "abcde".split(re"[bcd]+") == @["a", "e"]


# replace ------------------------------------------------------------------------------------------
proc replace*(s: string, r: Regex, by: string): string = nre.replace(s, r, by)

proc replace*(s: string, r: Regex, by: (proc (match: string): string)): string = nre.replace(s, r, by)

test "replace":
  assert replace("abcde", re"[bcd]", "_") == "a___e"
  assert replace("abcde", re"[bcd]", (match) => match.to_upper) == "aBCDe"


# find ---------------------------------------------------------------------------------------------
proc find*(s: string, r: Regex): Option[string] =
  let found = nre.find(s, r)
  if found.isSome: nre.match(found.get).some else: string.none

test "find":
  assert "abcde".find(re"[bcd]") == "b".some
  assert "abcde".find(re"[x]").is_none


# find_iter ---------------------------------------------------------------------------------------------
iterator find_iter*(s: string, r: Regex): string =
  for match in nre.find_iter(s, r): yield nre.match(match)

test "find_iter":
  assert to_seq("abcde".find_iter(re"[bcd]")) == @["b", "c", "d"]


# find_all -----------------------------------------------------------------------------------------
proc find_all*(s: string, r: Regex): seq[string] = to_seq(find_iter(s, r))

test "find_all":
  assert "abcde".find_all(re"[bcd]") == @["b", "c", "d"]
  assert "abcde".find_all(re"[x]") == @[]


# find1,2,3,4 --------------------------------------------------------------------------------------
proc find1*(s: string, r: Regex): string =
  let list = find_all(s, r)
  assert list.len == 1, "expected 1 but found {list.len} elements for {r.repr}"
  list[0]

proc find2*(s: string, r: Regex): (string, string) =
  let list = find_all(s, r)
  assert list.len == 2, "expected 2 but found {list.len} elements for {r.repr}"
  (list[0], list[1])

proc find3*(s: string, r: Regex): (string, string, string) =
  let list = find_all(s, r)
  assert list.len == 3, "expected 3 but found {list.len} elements for {r.repr}"
  (list[0], list[1], list[2])

proc find4*(s: string, r: Regex): (string, string, string, string) =
  let list = find_all(s, r)
  assert list.len == 4, "expected 4 but found {list.len} elements for {r.repr}"
  (list[0], list[1], list[2], list[3])

test "find1,2,3,4":
  assert "abc".find1(re"[b]") == "b"
  assert "abc".find2(re"[bc]") == ("b", "c")