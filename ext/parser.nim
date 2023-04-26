import base

type
  Parser* = ref object
    text_ref*: ref string
    i*:        int
    warnings*: seq[string]

proc init*(_: type[Parser], text: string, i = 0): Parser =
  Parser(text_ref: text.to_ref, i: i)

proc scopy*(pr: Parser): Parser =
  Parser(text_ref: pr.text_ref, i: pr.i, warnings: pr.warnings)

proc text*(pr: Parser): string =
  pr.text_ref[]

# proc is_finished*(pr: Parser): bool =
#   pr.i > pr.text.high

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
  # pr.i < pr.text.high

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

proc find*(pr: Parser, fn: (char) -> bool, shift = 0): int =
  var j = shift
  while true:
    let c = pr.get j
    if c.is_none: break
    if fn(c.get): return j
    j.inc
  -1

proc find*(pr: Parser, s: set[char], shift = 0): int =
  pr.find(((c) => c in s), shift)

proc fget*(pr: Parser, fn: ((char) -> bool), shift = 0): Option[char] =
  let i = pr.find(fn, shift)
  if i >= 0: return pr.get(i)

proc fget*(pr: Parser, s: set[char], shift = 0): Option[char] =
  pr.fget(((c) => c in s), shift)

test "find, fget":
  let pr = Parser.init("abcd", 1)
  check pr.find({'c'}) == 1
  check pr.fget({'c'}) == 'c'

proc remainder*(pr: Parser): string =
  pr.text[pr.i..pr.text.high]