import base, ./grams

proc intersect_count*[T](a, b: seq[T]): int =
  # a, b should be sorted
  # LODO could be improved with binary search
  assert a[0] < a[^1] and b[0] < b[^1], "must be sorted"
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
  Match* = tuple[score: float, l, h: int]
  ScoreConfig* = object
    # Performance optimisation, avoiding costly sliding window with cosine calculation if query and
    # document vectors are too different, i.e. counts of same tokens are below threshold.
    matching_tokens_treshold*: float
    # If next step window has same score, merging its bounds with the previous window
    # merge_bounds*: bool
    # Include only results that have higher score
    score_treshold*: float
    # Optional hint, that there should be at least n tokens for query
    minimal_tokens_hint*: int

proc match*(s: Match, text: string): string =
  text[s.l..s.h]

proc init*(_: type[ScoreConfig]): ScoreConfig =
  ScoreConfig(matching_tokens_treshold: 0.55, score_treshold: 0.55, minimal_tokens_hint: 6) # merge_bounds: true

proc score*[T](q: CountTable[T], q_len: int, qnorm: float, text: seq[T], config = ScoreConfig.init): seq[Match] =
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
        # if (not result.is_empty) and (h - 1 == result[^1].h): # If windows are interesected
          # result[^1].h = h # Merging with previous match it's the the next step window
        if (not result.is_empty) and (l < result[^1].h): # If windows are interesected choosing the best one
          if score > result[^1].score: result[^1] = (score, l, h).Match
        else:
          result.add (score, l, h).Match

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

proc score*[T](query, text: seq[T], config = ScoreConfig.init): seq[Match] =
  var q: CountTable[T]
  for token in query: q.inc token
  score(q, query.len, q.l2_norm, text, config)


type ScoreFn*[T] = (proc(doc: T, found: var seq[(Match, T)]))
proc build_score*[T](query: string, config = ScoreConfig.init): ScoreFn[T] =
  # Using bigrams for short queries and trigrams for long
  let q_tg = query.to_trigram_codes
  if q_tg.len < config.minimal_tokens_hint:
    let q = query.to_bigram_codes; let q_us = q.unique.sort
    proc score_bg(doc: T, found: var seq[(Match, T)]) =
      if (intersect_count(doc.bigrams_us, q_us) / q_us.len) < config.matching_tokens_treshold: return
      for sc in score(q, doc.bigrams, config):
        let (v, l, h) = sc
        found.add ((v, l, (h + 1)), doc)
    return score_bg
  else:
    let q = q_tg; let q_us = q.unique.sort
    proc score_tg(doc: T, found: var seq[(Match, T)]) =
      if (intersect_count(doc.trigrams_us, q_us) / q_us.len) < config.matching_tokens_treshold: return
      for sc in score(q, doc.bigrams, config):
        let (v, l, h) = sc
        found.add ((v, l, (h + 1)), doc)
    return score_tg

# Test ---------------------------------------------------------------------------------------------
test "cosine_similarity":
  check cosine_similarity("some te".to_bigrams,  "smme te".to_bigrams)  =~ 0.6666
  check cosine_similarity("some te".to_trigrams, "smme te".to_trigrams) =~ 0.5999

test "intersect_count":
  let q_tokens = "smme te".to_trigrams.unique.sort
  check:
    q_tokens.len == 5
    intersect_count("this is some text message".to_trigrams.unique.sort, q_tokens) == 3

proc test_score(text, query: string, tokenize: (proc(s: string): seq[string]), lh: (proc(l, h: int): (int, int)), config = ScoreConfig.init): seq[tuple[score: float, match: string]] =
  let query_gs = tokenize(query); let text_gs = tokenize(text)
  score(query_gs, text_gs, config).mapit:
    let (score, l, h) = it
    let (l2, h2) = lh(l, h)
    (score, text[l2..h2])

proc test_score_bg(text, query: string): seq[tuple[score: float, match: string]] =
  test_score(text, query, (s) => s.to_bigrams, (l, h) => (l, h + 1))

proc test_score_tg(text, query: string, config = ScoreConfig.init): seq[tuple[score: float, match: string]] =
  test_score(text, query, (s) => s.to_trigrams, (l, h) => (l, h + 2), config)

test "score":
  check:
    "this is some text message".test_score_tg("smme te").pick(match) == @["some te"]

# Use case -----------------------------------------------------------------------------------------
when is_main_module:
  type
    Doc = ref object
      text:        string
      bigrams:     seq[int]
      bigrams_us:  seq[int] # unique sorted
      trigrams:    seq[int]
      trigrams_us: seq[int] # unique sorted
    Db = ref object
      docs: seq[Doc]

  proc init(_: type[Doc], text: string): Doc =
    let (bigrams, trigrams) = (text.to_bigram_codes, text.to_trigram_codes) # Pre-indexing document
    Doc(text: text,
      bigrams: bigrams,   bigrams_us: bigrams.unique.sort,
      trigrams: trigrams, trigrams_us: trigrams.unique.sort
    )

let db = Db(docs: [
  "this is smme text message",
  "this is some text message",
  "another message"
].mapit(Doc.init(it)))

let score_fn: ScoreFn[Doc] = build_score[Doc]("some te")
var found: seq[(Match, Doc)]
for doc in db.docs: score_fn(doc, found)
p found
  .sortit(-it[0].score) # Sorting by score
  .mapit(match(it[0], it[1].text)) # => @["some te", "smme te"]