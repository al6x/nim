import base

type
  Parser* = ref object
    text*:  string
    i*:     int
    warns*: seq[string]

proc init*(_: type[Parser], text: string, i = 0): Parser =
  Parser(text: text, i: i)

proc deep_copy*(pr: Parser): Parser =
  Parser(text: pr.text, i: pr.i, warns: pr.warns)

proc get*(pr: Parser, shift = 0): Option[char] =
  let i = pr.i + shift
  if i >= 0 and i < pr.text.len: pr.text[i].some else: char.none

iterator items*(pr: Parser, shift = 0): char =
  var i = pr.i + shift; let len = pr.text.len
  while i < len:
    yield pr.text[i]
    i.inc

proc has*(pr: Parser, shift = 0): bool =
  let i = pr.i + shift
  i >= 0 and i < pr.text.len

proc has_next*(pr: Parser): bool =
  pr.has(1)

proc inc*(pr: Parser) =
  if pr.i < pr.text.len: pr.i.inc

proc skip*(pr: Parser, fn: (char) -> bool, shift = 0) =
  pr.i += shift
  while pr.has:
    if not fn(pr.get.get): break
    pr.inc

proc skip*(pr: Parser, s: set[char], shift = 0) =
  pr.skip(((c) => c in s), shift)

proc consume*(pr: Parser, fn: (char) -> bool, shift = 0): string =
  pr.i += shift
  while pr.has:
    if not fn(pr.get.get): break
    result.add pr.get.get
    pr.inc

proc consume*(pr: Parser, s: set[char], shift = 0): string =
  pr.consume(((c) => c in s), shift)

test "consume":
  let pr = Parser.init("abbc", 1)
  check pr.consume({'b'}) == "bb"
  check pr.i == 3

proc find*(pr: Parser, fn: (char) -> bool, shift = 0, limit = -1): int =
  var j = shift
  while true:
    if limit >= 0 and j > limit: break
    let c = pr.get j
    if c.is_none: break
    if fn(c.get): return j
    j.inc
  -1

proc find*(pr: Parser, s: set[char], shift = 0, limit = -1): int =
  pr.find(((c) => c in s), shift = shift, limit = limit)

proc fget*(pr: Parser, fn: ((char) -> bool), shift = 0, limit = -1): Option[char] =
  let i = pr.find(fn, shift = shift, limit = limit)
  if i >= 0: return pr.get(i)

proc fget*(pr: Parser, s: set[char], shift = 0, limit = -1): Option[char] =
  pr.fget(((c) => c in s), shift = shift, limit = limit)

proc starts_with*(pr: Parser, s: string, shift = 0): bool =
  for j, c in s:
    let i = pr.i + shift + j
    if i > pr.text.high or s[j] != pr.text[i]: return false
  true

test "find, fget":
  let pr = Parser.init("abcd", 1)
  check pr.find({'c'}) == 1
  check pr.fget({'c'}) == 'c'

proc remainder*(pr: Parser): string =
  pr.text[pr.i..pr.text.high]

# proc before_after*(pr: Parser): string =
#   # for debug
#   let before = pr.text[(pr.text.low, pr.i - 5).max..(pr.text.low, pr.i - 1).max]
#   let after  = pr.text[(pr.text.high, pr.i + 1).min..(pr.text.high, pr.i + 5).min]
#   fmt"{before}|{pr.get}|{after}"