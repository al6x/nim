import base

import std/[hashes, tables]

type Trigram = array[3, char]

proc `==`(a, b: Trigram): bool {.inline.} =
  a[0] == b[0] and a[1] == b[1] and a[2] == b[2]

proc hash(t: Trigram): Hash {.inline.} =
  !$(t[0].hash !& t[1].hash !& t[2].hash)

proc init*(_: type[Trigram], s: string, i: int): Trigram {.inline.} =
  [s[i], s[i+1], s[i+2]]

var codes: Table[Trigram, int]
template encode_trigram*(s: Trigram): int =
  codes.mget_or_put(s, codes.len)

proc to_trigrams*(text: string, result: var seq[int]) =
  case text.len
  of 0: discard
  of 1: result.add [text[^1], ' ',      ' '].Trigram.encode_trigram
  of 2: result.add [text[^2], text[^1], ' '].Trigram.encode_trigram
  else:
    for i in 0..(text.len - 3):
      result.add Trigram.init(text, i).encode_trigram
    result.add [text[^2], text[^1], ' '].Trigram.encode_trigram
    result.add [text[^1], ' ',      ' '].Trigram.encode_trigram

proc to_trigrams*(text: string): seq[int] {.inline.} =
  to_trigrams(text, result)

proc count_same_sorted*(a: seq[int], b: seq[int]): int =
  var i = 0; var j = 0
  while i < a.len and j < b.len:
    if   a[i] < b[j]: i.inc
    elif a[i] > b[j]: j.inc
    else:             result.inc; i.inc; j.inc

when is_main_module:
  echo "some text".to_trigrams # => @[0, 1, 2, 3, 4, 5, 6, 7, 8]
  echo "some".to_trigrams # => @[0, 1, 2, 9]