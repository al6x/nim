import base, mono/[core, http], ext/[grams, search]
import ../../model, ../../render/blocks, ./helpers, ../palette as pl, ./location

type FilterView* = ref object of Component
  initial_filter*: Filter
  query*: string

proc after_create*(self: FilterView) =
  self.query = self.initial_filter.to_s # Setting the initial query from url

proc safe_substring(s: string, l, h: int): string =
  assert l < h
  s[max(0, min(s.high, l))..min(s.high, max(0, h))]

proc InfoMessage(message: string): El =
  el(PRBlock, (tname: "prblock-filter-info")):
    el".text-sm.text-gray-400":
      it.text message

proc Tags[T](tags: seq[string], filter: Filter, filter_view: T): El =
  proc incl_or_excl_tag(tag: int): proc(e: ClickEvent) =
    proc(e: ClickEvent) =
      var f = filter
      f.excl.deleteit(it == tag); f.incl.deleteit(it == tag)
      if shift in e.special_keys: f.excl = (f.excl & @[tag]).sort
      else:                       f.incl = (f.incl & @[tag]).sort
      filter_view.query = f.to_s

  proc deselect_tag(tag: int): proc(e: ClickEvent) =
    proc(e: ClickEvent) =
      var f = filter
      let excl = tag in f.incl and shift in e.special_keys
      f.excl.deleteit(it == tag); f.incl.deleteit(it == tag)
      if excl: f.excl = (f.excl & @[tag]).sort
      filter_view.query = f.to_s

  let no_selected = filter.incl.is_empty and filter.excl.is_empty
  el(PTags, ()):
    for tag in tags:
      capt tag:
        let tcode = tag.encode_tag
        if   tcode in filter.incl:
          alter_el(el(PTag, (text: tag, style: included))):
            it.attr("href", "#")
            it.on_click deselect_tag(tcode)
        elif tcode in filter.excl:
          alter_el(el(PTag, (text: tag, style: excluded))):
            it.attr("href", "#")
            it.on_click deselect_tag(tcode)
        elif no_selected:
          alter_el(el(PTag, (text: tag, style: normal))):
            it.attr("href", "#")
            it.on_click incl_or_excl_tag(tcode)
        else:
          alter_el(el(PTag, (text: tag, style: ignored))):
            it.attr("href", "#")
            it.on_click incl_or_excl_tag(tcode)

proc render_search*(self: FilterView, filter: Filter): El =
  let side_text_len = (db.config.text_around_match_len.get(200) / 2).ceil.int
  let all_tags = db.ntags_cached.keys.map(decode_tag).sort
  let tic = timer_ms()
  let query_ready = filter.query.len >= 3
  var blocks: seq[Matches[Block]]
  if query_ready: blocks = db.search_blocks(filter.incl, filter.excl, filter.query).to_seq
  let message = if query_ready:
    fmt"""Found {blocks.len} {blocks.len.pluralize("block")} in {tic()}ms"""
  else:
    "Query should have at least 3 symbols"

  let right = els:
    alter_el(el(PSearchField, ()), it.bind_to(self.query))
    el(InfoMessage, (message: message))
    el(Tags, (tags: all_tags, filter: filter, filter_view: self))

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
  let all_tags = db.ntags_cached.keys.map(decode_tag)
  let tic = timer_ms()
  let filter_ready = not (filter.incl.is_empty and filter.excl.is_empty)
  var blocks: seq[Block]
  if filter_ready: blocks = db.filter_blocks(filter.incl, filter.excl).to_seq
  let message = if filter_ready:
    fmt"""Found {blocks.len} {blocks.len.pluralize("block")} in {tic()}ms"""
  else:
    "Select at least one tag"

  let right = els:
    alter_el(el(PSearchField, ()), it.bind_to(self.query))
    el(InfoMessage, (message: message))
    el(Tags, (tags: all_tags, filter: filter, filter_view: self))

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