import supportm, optionm, strutils, sugar, sequtils, strformat
from std/nre as nre import nil
from std/options as stdoptions import nil

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
  if stdoptions.is_some(found): nre.match(stdoptions.get(found)).some else: return

test "find":
  assert "abcde".find(re"[bcd]") == "b".some
  assert "abcde".find(re"[x]").is_none


# parse --------------------------------------------------------------------------------------------
proc parse*(r: Regex, s: string): Option[seq[string]] =
  let found = nre.match(s, r)
  if stdoptions.is_some(found):
    to_seq(nre.items(nre.captures(stdoptions.get(found)))).map((o) => stdoptions.get(o)).some
  else:
    return

test "parse":
  assert re".+ (\d+) (\d+)".parse("a 22 45") == @["22", "45"].some

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

# parse1,2,3,4 --------------------------------------------------------------------------------------
proc parse1*(r: Regex, s: string): Option[string] =
  let foundo = r.parse(s)
  if foundo.is_none: return
  let found = foundo.get
  if found.len == 1: found[0].some else: return

proc parse2*(r: Regex, s: string): Option[(string, string)] =
  let foundo = r.parse(s)
  if foundo.is_none: return
  let found = foundo.get
  if found.len == 2: (found[0], found[1]).some else: return

proc parse3*(r: Regex, s: string): Option[(string, string, string)] =
  let foundo = r.parse(s)
  if foundo.is_none: return
  let found = foundo.get
  if found.len == 3: (found[0], found[1], found[2]).some else: return

proc parse4*(r: Regex, s: string): Option[(string, string, string, string)] =
  let foundo = r.parse(s)
  if foundo.is_none: return
  let found = foundo.get
  if found.len == 4: (found[0], found[1], found[2], found[3]).some else: return

proc parse5*(r: Regex, s: string): Option[(string, string, string, string, string)] =
  let foundo = r.parse(s)
  if foundo.is_none: return
  let found = foundo.get
  if found.len == 4: (found[0], found[1], found[2], found[3], found[4]).some else: return

test "parse1,2,3,4,5":
  let pattern = re".+ (\d+) (\d+)"
  assert pattern.parse2("a 22 45") == ("22", "45").some
  assert pattern.parse2("a 22").is_none