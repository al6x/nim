import base

# Bigrams -----------------------------------------------------------------------------------------
type Bigram = array[2, char]

proc init*(_: type[Bigram], s: string, i: int): Bigram {.inline.} =
  [s[i], s[i+1]]

proc `==`(a, b: Bigram): bool {.inline.} =
  a[0] == b[0] and a[1] == b[1]

proc hash(t: Bigram): Hash {.inline.} =
  !$(t[0].hash !& t[1].hash)

proc `$`(t: Bigram): string =
  t[0] & t[1]

var bigram_codes: Table[Bigram, int]
template encode_bigram*(s: Bigram): int =
  bigram_codes.mget_or_put(s, bigram_codes.len)

var bigram_rcodes: Table[int, Bigram]
proc rebuild_bigram_rcodes =
  for g, c in bigram_codes:
    if c notin bigram_rcodes: bigram_rcodes[c] = g

proc decode_bigram*(code: int): Bigram =
  if code notin bigram_rcodes: rebuild_bigram_rcodes()
  bigram_rcodes[code]

proc to_bigram_codes*(text: string, result: var seq[int]) =
  case text.len
  of 0: discard
  of 1: result.add [text[0], ' '].Bigram.encode_bigram
  else:
    for i in 0..(text.len - 2):
      result.add Bigram.init(text, i).encode_bigram
    # result.add [text[^1], ' '     ].Bigram.encode_bigram

proc to_bigram_codes*(text: string): seq[int] {.inline.} =
  to_bigram_codes(text, result)

proc to_bigrams*(text: string): seq[string] =
  case text.len
  of 0: discard
  of 1: result.add text & " "
  else:
    for i in 0..(text.len - 2):
      result.add text[i..(i + 1)]

# Trigrams -----------------------------------------------------------------------------------------
type Trigram = array[3, char]

proc init*(_: type[Trigram], s: string, i: int): Trigram {.inline.} =
  [s[i], s[i+1], s[i+2]]

proc `==`(a, b: Trigram): bool {.inline.} =
  a[0] == b[0] and a[1] == b[1] and a[2] == b[2]

proc hash(t: Trigram): Hash {.inline.} =
  !$(t[0].hash !& t[1].hash !& t[2].hash)

proc `$`(t: Trigram): string =
  t[0] & t[1] & t[2]

var trigram_codes: Table[Trigram, int]
template encode_trigram*(s: Trigram): int =
  trigram_codes.mget_or_put(s, trigram_codes.len)

var trigram_rcodes: Table[int, Trigram]
proc rebuild_trigram_rcodes =
  for g, c in trigram_codes:
    if c notin trigram_rcodes: trigram_rcodes[c] = g

proc decode_trigram*(code: int): Trigram =
  if code notin trigram_rcodes: rebuild_trigram_rcodes()
  trigram_rcodes[code]

proc to_trigram_codes*(text: string, result: var seq[int]) =
  case text.len
  of 0: discard
  of 1: result.add [text[0], ' ',      ' '].Trigram.encode_trigram
  of 2: result.add [text[0], text[1], ' '].Trigram.encode_trigram
  else:
    for i in 0..(text.len - 3):
      result.add Trigram.init(text, i).encode_trigram

proc to_trigram_codes*(text: string): seq[int] {.inline.} =
  to_trigram_codes(text, result)

proc to_trigrams*(text: string): seq[string] {.inline.} =
  case text.len
  of 0: discard
  of 1: result.add text & "  "
  of 2: result.add text & " "
  else:
    for i in 0..(text.len - 3):
      result.add text[i..(i + 2)]

test "to_trigrams":
  check:
    "some text".to_trigram_codes == @[0, 1, 2, 3, 4, 5, 6]
    "some".to_trigram_codes == @[0, 1]