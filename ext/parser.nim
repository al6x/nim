import base

type
  Parser* = object
    text_ref*: ref string
    i*:        int
    warnings*: seq[string]

proc init*(_: type[Parser], text: string, i = 0): Parser =
  Parser(text_ref: text.to_ref, i: i)

proc text*(pr: Parser): string =
  pr.text_ref[]

proc is_finished*(pr: Parser): bool =
  pr.i > pr.text.high

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

proc inc*(pr: var Parser) =
  if pr.i < pr.text.len: pr.i.inc

proc skip*(pr: var Parser, fn: (Parser) -> bool) =
  while not pr.is_finished:
    if not fn(pr): break
    pr.inc

proc skip*(pr: var Parser, s: set[char]) =
  pr.skip (pr) => pr.get in s

proc consume*(pr: var Parser, fn: (Parser) -> bool): string =
  while not pr.is_finished:
    if not fn(pr): break
    result.add pr.get.get
    pr.inc

proc consume*(pr: var Parser, s: set[char]): string =
  pr.consume (pr) => pr.get in s

test "consume":
  var pr = Parser.init("abbc", 1)
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
  var pr = Parser.init("abcd", 1)
  check pr.find({'c'}) == 1
  check pr.fget({'c'}) == 'c'