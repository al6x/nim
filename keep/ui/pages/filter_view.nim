import base, mono/[core, http], ext/[grams, search]
import ../../model, ../helpers, ../support, ../../render/blocks, ../palette as pl, ../partials/[filter_tags, query_input], ../location

proc FilterView*(query_input: QueryInput, page: int): El =
  let tic = timer_ms()
  let filter = query_input.filter
  let filter_ready = not (filter.incl.is_empty and filter.excl.is_empty)
  var records: seq[Record]
  if filter_ready: records = db.filter(filter.incl, filter.excl).to_seq
  let message = if filter_ready:
    fmt"""Found {records.len} in {tic()}ms"""
  else:
    "Select at least one tag"

  let right = els:
    it.add query_input.render
    el(PSearchInfo, (message: message))
    el(FilterTags, (query_input: query_input))

  let right_down = els:
    el(Warns, ())

  let per_page = db.config.per_page
  proc page_url(page: int): string = filter_url(filter, page)
  let view =
    el(PApp, ( # App
      show_block_separator: true,
      title: "Filter".some, title_hint: "",
      right: right, right_down: right_down
    )):
      for record in records.paginate(page = page, per_page = per_page):
        if record of Block:
          let blk = record.Block
          let context = RenderContext.init(blk.sid, mono_id)
          let blk_link = build_el(PIconLink, (icon: "link", url: blk.short_url))
          el(PBlock, (blk: blk, context: context, controls: @[blk_link], hover: false))
        else:
          throw "record not implemented"

      el(PPagination, (count: records.len, page: page, per_page: per_page, url: page_url))

  view.window_title "Filter"
  view