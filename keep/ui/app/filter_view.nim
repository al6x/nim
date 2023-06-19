import base, mono/[core, http]
import ../../model, ../../render/blocks, ./helpers, ../palette as pl, ./location

type FilterView* = ref object of Component
  initial_filter*: Filter
  query*: string

proc after_create*(self: FilterView) =
  self.query = self.initial_filter.to_s # Setting the initial query from url

proc safe_substring(s: string, l, h: int): string =
  assert l < h
  s[max(0, min(s.high, l))..min(s.high, max(0, h))]

proc render_search*(self: FilterView, filter: Filter): El =
  let blocks = db.search_blocks(filter.incl, filter.excl, filter.query).to_seq
  let side_text_len = (db.config.text_around_match_len.get(200) / 2).ceil.int

  let tic = timer_ms()
  let all_tags = db.ntags_cached.keys.map(decode_tag)
  let right = els:
    # el(PTags, (tags: all_tags.with_path(context)))
    alter_el(el(PSearchField, ()), it.bind_to(self.query))
    # el(PTags, (tags: data.tags.with_path(context), disabled: @["Taxes", "Currency", "Stock"]))
    el(PRBlock, (tname: "prblock-filter-info", title: "Info")):
      el".text-sm.text-gray-400":
        it.text fmt"""Found {blocks.len} {blocks.len.pluralize("block")} in {tic()}ms"""

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
        el(PFoundBlock, (title: blk.doc.title.if_empty(blk.doc.id), matches: matches))

  view.window_title "Search"
  view.window_location filter.filter_url
  view

proc render_filter*(self: FilterView, filter: Filter): El =
  let blocks = db.filter_blocks(filter.incl, filter.excl).to_seq

  let tic = timer_ms()
  let all_tags = db.ntags_cached.keys.map(decode_tag)
  let right = els:
    # el(PTags, (tags: all_tags.with_path(context)))
    alter_el(el(PSearchField, ()), it.bind_to(self.query))
    # el(PTags, (tags: data.tags.with_path(context), disabled: @["Taxes", "Currency", "Stock"]))
    el(PRBlock, (tname: "prblock-filter-info", title: "Info")):
      el".text-sm.text-gray-400":
        it.text fmt"""Found {blocks.len} {blocks.len.pluralize("block")} in {tic()}ms"""

  let right_down = els:
    el(Warns, ())

  let view =
    el(PApp, ( # App
      title: "Filter", title_hint: "",
      right: right, right_down: right_down
    )):
      for blk in blocks: # Blocks
        let context = RenderContext.init(blk.doc, blk.doc.space.id)
        el(PBlock, (blk: blk, context: context, controls: edit_btn(blk).to_seq))

  view.window_title "Filter" #doc.title
  view.window_location filter.filter_url
  view

proc render*(self: FilterView): El =
  let filter = Filter.parse self.query
  if filter.query.is_empty: self.render_filter(filter) else: self.render_search(filter)