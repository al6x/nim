import base, mono/[core, http]
import ../../model, ../helpers, ../palette as pl, ../partials/[filter_tags, query_input], ../location
from std/algorithm import sort

proc safe_substring(s: string, l, h: int): string =
  assert l < h
  s[max(0, min(s.high, l))..min(s.high, max(0, h))]

proc SearchView*(query_input: QueryInput, page: int): El =
  let tic = timer_ms()
  let filter = query_input.filter
  let query_ready = filter.query.len >= 3
  var found: seq[Matches]
  if query_ready: found = db.search_substring(filter.incl, filter.excl, filter.query).to_seq
  let message = if query_ready:
    fmt"""Found {found.len} in {tic()}ms"""
  else:
    "Query should have at least 3 symbols"

  found.sort proc (a, b: Matches): int = # Sorting first by score and then by record.id
    let r = cmp(b.score, a.score)
    if r != 0: return r
    cmp(a.record.id, b.record.id)

  let right = els:
    it.add query_input.render
    el(PSearchInfo, (message: message))
    el(FilterTags, (query_input: query_input))

  let right_down = els:
    el(Warns, ())

  let side_text_len = db.config.text_around_match_len; let per_page = db.config.per_page
  proc page_url(page: int): string = filter_url(filter, page)
  let view =
    el(PApp, ( # App
      show_block_separator: true,
      title: "Found".some, title_hint: "",
      right: right, right_down: right_down
    )):
      for (best_score, record, record_matches) in found.paginate(page = page, per_page = per_page): # Records
        var matches: seq[PFoundItem]
        for (score, bounds) in record_matches:
          let l = bounds.a; let h = bounds.b
          let before = if l > 0: record.text.safe_substring(l - side_text_len, l - 1) else: ""
          let match  = record.text.safe_substring(l, h)
          let after  = if h < record.text.high: record.text.safe_substring(h + 1, h + side_text_len) else: ""
          matches.add (before, match, after)
        el(PFoundBlock, (
          title:    record.record_title,
          matches:  matches,
          url:      record.url,
        ))

      el(PPagination, (count: found.len, page: page, per_page: per_page, url: page_url))

  view.window_title "Search"
  view