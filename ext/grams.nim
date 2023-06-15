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

# Search -------------------------------------------------------------------------------------------
proc intersect_count*(a, b: seq[int]): int =
  # a, b should be sorted
  # LODO could be improved with binary search
  var i = 0; var j = 0
  while i < a.len and j < b.len:
    if   a[i] < b[j]: i.inc
    elif a[i] > b[j]: j.inc
    else:             result.inc; i.inc; j.inc

template l2_norm[T](v: CountTable[T]): float {.inject.} =
  var sum = 0
  for _, count in v: sum += count * count
  sum.float.sqrt

proc cosine_similarity[T](q, w: CountTable[T], qnorm: float): float {.inject.} =
  var dot_prod = 0
  for token, count in q: dot_prod += count * w[token]
  dot_prod.float / (qnorm * w.l2_norm)

proc count_tokens[T](tokens: seq[T]): CountTable[T] =
  for token in tokens: result.inc token

proc cosine_similarity[T](a, b: seq[T]): float {.inject.} =
  let a_counts = a.count_tokens
  cosine_similarity(a_counts, b.count_tokens, a_counts.l2_norm)

type
  Score* = tuple[score: float, l, h: int]
  ScoreConfig* = object
    # matching_tokens_treshold - performance optimisation, avoiding costly cosine calculation if query and
    # window vectors are too different, i.e. counts of same tokens are below threshold.
    matching_tokens_treshold*: float
    # If next step window has same score, merging its bounds with the previous window
    merge_bounds*: bool
    # Include only results that have higher score
    score_treshold*: float

proc init*(_: type[ScoreConfig]): ScoreConfig =
  ScoreConfig(matching_tokens_treshold: 0.6, merge_bounds: true, score_treshold: 0.55)

proc score*[T](q: CountTable[T], q_len: int, qnorm: float, text: seq[T], config = ScoreConfig.init): seq[Score] =
  # Sliding window counts and bounds
  var w: CountTable[T]
  var same_count = 0
  var l = 0; var h = min(q_len - 1, text.high)
  # var score = (-1.0, -1, -1).Score

  # Sliding counts and score
  template add(token: T) =
    w.inc token
    if token in q: same_count.inc
  template del(token: T) =
    w.inc token, -1
    if token in q: same_count.dec
  template calc_score =
    # p w, cosine_similarity(q, w, qnorm)
    if (same_count / q.len) >= config.matching_tokens_treshold:
      let score = cosine_similarity(q, w, qnorm)
      if score > config.score_treshold:
        if (not result.is_empty) and (h - 1 == result[^1].h):
          result[^1].h = h # Merging with previous match it's the the next step window
        else:
          result.add (score, l, h).Score

  # Populating initial `w` vector and score
  for i in l..h: add(text[i])
  calc_score()

  # Moving window
  if text.len > q_len:
    for i in 1..(text.len - q_len):
      l = i
      h = l + q_len - 1

      del text[l-1]
      add text[h]
      calc_score()

  # if score.score > 0.0: result = score.some

proc score*[T](query, text: seq[T], config = ScoreConfig.init): seq[Score] =
  var q: CountTable[T]
  for token in query: q.inc token
  score(q, query.len, q.l2_norm, text, config)

proc score[T](text, query: string, tokenize: (proc(s: string): seq[T]), lh: (proc(l, h: int): (int, int)), config = ScoreConfig.init): seq[tuple[score: float, match: string]] =
  let query_gs = tokenize(query); let text_gs = tokenize(text)
  score(query_gs, text_gs, config).mapit:
    let (score, l, h) = it
    let (l2, h2) = lh(l, h)
    (score, text[l2..h2])

proc score_bg(text, query: string): seq[tuple[score: float, match: string]] =
  score[string](text, query, (s) => s.to_bigrams, (l, h) => (l, h + 1))

proc score_tg(text, query: string, config = ScoreConfig.init): seq[tuple[score: float, match: string]] =
  score[string](text, query, (s) => s.to_trigrams, (l, h) => (l, h + 2), config)

test "to_trigrams":
  check:
    "some text".to_trigram_codes == @[0, 1, 2, 3, 4, 5, 6]
    "some".to_trigram_codes == @[0, 1]

test "cosine_similarity":
  check cosine_similarity("some te".to_bigrams,  "smme te".to_bigrams)  =~ 0.6666
  check cosine_similarity("some te".to_trigrams, "smme te".to_trigrams) =~ 0.5999

test "score":
  check:
    "this is some text message".score_tg("smme te").pick(match) == @["some text"]