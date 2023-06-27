import base, mono/[core, http], ext/[grams, search]
import ../../model, ../helpers, ../palette as pl, ../partials/[filter_tags, query_input], ../location

proc safe_substring(s: string, l, h: int): string =
  assert l < h
  s[max(0, min(s.high, l))..min(s.high, max(0, h))]

proc SearchView*(query_input: QueryInput): El =
  let side_text_len = (db.config.text_around_match_len.get(200) / 2).ceil.int
  let tic = timer_ms()
  let filter = query_input.filter
  let query_ready = filter.query.len >= 3
  var blocks: seq[Matches[Block]]
  if query_ready: blocks = db.search_blocks(filter.incl, filter.excl, filter.query).to_seq
  let message = if query_ready:
    fmt"""Found {blocks.len} {blocks.len.pluralize("block")} in {tic()}ms"""
  else:
    "Query should have at least 3 symbols"

  let right = els:
    it.add query_input.render
    el(PSearchInfo, (message: message))
    el(FilterTags, (query_input: query_input))

  let right_down = els:
    el(Warns, ())

  let view =
    el(PApp, ( # App
      show_block_separator: true,
      title: "Found", title_hint: "",
      right: right, right_down: right_down
    )):
      for (best_score, blk, blk_matches) in blocks: # Blocks
        var matches: seq[PFoundItem]
        for (score, l, h) in blk_matches:
          let before = blk.text.safe_substring(l - side_text_len, l - 1)
          let match  = blk.text.safe_substring(l, h)
          let after  = blk.text.safe_substring(h + 1, h + side_text_len)
          matches.add (before, match, after)
        el(PFoundBlock, (
          title:    blk.doc.title.if_empty(blk.doc.id),
          matches:  matches,
          url:      blk.short_url,
        ))

  view.window_title "Search"
  view