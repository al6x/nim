import base, ./grams


# Helpers ------------------------------------------------------------------------------------------
proc intersect_count*[T](a, b: seq[T]): int =
  # a, b should be sorted
  # LODO could be improved with binary search
  assert a[0] < a[^1] and b[0] < b[^1], "must be sorted"
  var i = 0; var j = 0
  while i < a.len and j < b.len:
    if   a[i] < b[j]: i.inc
    elif a[i] > b[j]: j.inc
    else:             result.inc; i.inc; j.inc

proc is_all_in*[T](subset, superset: seq[T]): bool {.inline.} =
  var i = 0; var j = 0
  while i < subset.len and j < superset.len:
    if   subset[i] < superset[j]: return false
    elif subset[i] > superset[j]: j.inc
    else:
      i.inc; j.inc
  i == subset.len

proc is_none_in*[T](s1, s2: seq[T]): bool {.inline.} =
  # s1, s2 should be sorted
  var i = 0; var j = 0
  while i < s1.len and j < s2.len:
    if   s1[i] < s2[j]: i.inc
    elif s1[i] > s2[j]: j.inc
    else:               return false
  true

# Search -------------------------------------------------------------------------------------------
template l2_norm[T](v: Table[T, int]): float {.inject.} =
  var sum = 0
  for _, count in v: sum += count * count
  sum.float.sqrt

proc cosine_similarity[T](q, w: Table[T, int], qnorm: float): float {.inject.} =
  var dot_prod = 0
  for token, count in q: dot_prod += count * w.get(token, 0)
  dot_prod.float / (qnorm * w.l2_norm)

proc count_tokens[T](tokens: seq[T]): Table[T, int] =
  for token in tokens: result.inc token

proc cosine_similarity[T](a, b: seq[T]): float {.inject.} =
  let a_counts = a.count_tokens
  cosine_similarity(a_counts, b.count_tokens, a_counts.l2_norm)

type
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

  Match* = tuple[score: float, l, h: int]
  Matches*[D] = tuple[score: float, doc: D, matches: seq[Match]]
  ScoreFn*[D] = proc(doc: D, result: var seq[Matches[D]])

  AlterMatchBounds* = proc(l, h: int): (int, int)

let alter_bigram_bounds:  AlterMatchBounds = proc(l, h: int): (int, int) = (l, h + 1)
let alter_trigram_bounds: AlterMatchBounds = proc(l, h: int): (int, int) = (l, h + 2)

proc match*(m: Match, text: string): string =
  text[m.l..m.h]

proc init*(_: type[ScoreConfig]): ScoreConfig =
  ScoreConfig(matching_tokens_treshold: 0.55, score_treshold: 0.55, minimal_tokens_hint: 6) # merge_bounds: true

proc score*[D, T](q: Table[T, int], q_len: int, qnorm: float, text: seq[T], config = ScoreConfig.init, doc: D, result: var seq[Matches[D]], alter_bounds = AlterMatchBounds.none) =
  # Sliding window counts and bounds
  var w: Table[T, int]
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

  var added = false
  template calc_score =
    # p w, cosine_similarity(q, w, qnorm)
    if (same_count / q.len) >= config.matching_tokens_treshold:
      let score = cosine_similarity(q, w, qnorm)
      if score > config.score_treshold:
        # if (not result.is_empty) and (h - 1 == result[^1].h): # If windows are interesected
          # result[^1].h = h # Merging with previous match it's the the next step window

        unless added:
          result.add (score: score, doc: doc, matches: seq[Match].init)
          added = true

        let (l2, h2) = if alter_bounds.is_some: (alter_bounds.get)(l, h) else: (l, h)
        if not result[^1].matches.is_empty and l < result[^1].matches[^1].h:
          # If windows are interesected choosing the best one
          if score > result[^1].matches[^1].score: result[^1].matches[^1] = (score, l2, h2).Match
        else:
          result[^1].matches.add (score, l2, h2).Match

        result[^1].matches = result[^1].matches.sortit(it.score)
        result[^1].score   = result[^1].matches[0].score

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

proc score*[D, T](query, text: seq[T], config = ScoreConfig.init, doc: D, result: var seq[Matches[D]], alter_bounds = AlterMatchBounds.none) =
  var q: Table[T, int]
  for token in query: q.inc token
  score(q, query.len, q.l2_norm, text, config, doc, result, alter_bounds)

proc build_score*[D](query: string, config = ScoreConfig.init): ScoreFn[D] =
  # Using bigrams for short queries and trigrams for long
  let q_tg = query.to_trigram_codes
  if q_tg.len < config.minimal_tokens_hint:
    let q = query.to_bigram_codes; let q_us = q.unique.sort
    proc score_bg(doc: D, result: var seq[Matches[D]]) =
      if (intersect_count(doc.bigrams_us, q_us) / q_us.len) >= config.matching_tokens_treshold:
        score(q, doc.bigrams, config, doc, result, alter_bounds = alter_bigram_bounds.some)
    return score_bg
  else:
    let q = q_tg; let q_us = q.unique.sort
    proc score_tg(doc: D, result: var seq[Matches[D]]) =
      if (intersect_count(doc.trigrams_us, q_us) / q_us.len) >= config.matching_tokens_treshold:
        score(q, doc.bigrams, config, doc, result, alter_bounds = alter_trigram_bounds.some)
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

proc test_score(text, query: string, tokenize: (proc(s: string): seq[string]), config = ScoreConfig.init, alter_bounds = AlterMatchBounds.none): seq[tuple[score: float, match: string]] =
  let query_gs = tokenize(query); let text_gs = tokenize(text)
  var r: seq[Matches[string]]
  score(query_gs, text_gs, config, doc = text, r, alter_bounds = alter_bounds)
  for (best_score, doc, matches) in r:
    for (score, l, h) in matches:
      result.add (score, doc[l..h])

proc test_score_bg(text, query: string): seq[tuple[score: float, match: string]] =
  # let lh: AlterMatchBounds = proc (l, h: int): (int, int) = (l, h + 1)
  test_score(text, query, ((s) => s.to_bigrams), ScoreConfig.init, alter_bounds = alter_bigram_bounds.some)

proc test_score_tg(text, query: string): seq[tuple[score: float, match: string]] =
  # test_score(text, query, (s) => s.to_trigrams, (l, h) => (l, h + 2), config)
  # let lh: AlterMatchBounds = proc (l, h: int): (int, int) = (l, h + 2)
  test_score(text, query, ((s) => s.to_trigrams), ScoreConfig.init, alter_bounds = alter_trigram_bounds.some)

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
  var found: seq[Matches[Doc]]
  for doc in db.docs: score_fn(doc, found)
  found = found.sortit(-it.score) # Sorting by score
  for (best_score, doc, matches) in found:
    for match in matches:
      p match(match, doc.text) # => @["some te", "smme te"]