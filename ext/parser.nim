import base

type
  Warning = tuple[message: string, data: JsonNode]

  Parser* = object
    text_ref*: ref string
    i*:        int
    warnings*: seq[Warning]

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

proc has_next*(pr: Parser): bool =
  pr.i < pr.text.high

proc inc*(pr: var Parser) =
  if pr.i < pr.text.len: pr.i.inc

proc skip*(pr: var Parser, fn: (Parser) -> bool) =
  while not pr.is_finished:
    if not fn(pr): break
    pr.inc

proc skip*(pr: var Parser, s: set[char]) =
  pr.skip (pr) => pr.get in s

# type CollectCommand* = enum cmaybe, abort, finish

proc collect*(pr: var Parser, fn: (Parser) -> bool): string =
  while not pr.is_finished:
    if not fn(pr): break
    result.add pr.get.get
    pr.inc

proc collect*(pr: var Parser, s: set[char]): string =
  pr.collect (pr) => pr.get in s

test "collect":
  var pr = Parser.init("abbc", 1)
  check pr.collect({'b'}) == "bb"
  check pr.i == 3