import base, mono/[core, http], ext/[grams, search]
import ../../model, ../helpers, ../../render/blocks, ../palette as pl, ../partials/[filter_tags, query_input], ../location

proc FilterView*(query_input: QueryInput): El =
  let tic = timer_ms()
  let filter = query_input.filter
  let filter_ready = not (filter.incl.is_empty and filter.excl.is_empty)
  var blocks: seq[Block]
  if filter_ready: blocks = db.filter_blocks(filter.incl, filter.excl).to_seq
  let message = if filter_ready:
    fmt"""Found {blocks.len} {blocks.len.pluralize("block")} in {tic()}ms"""
  else:
    "Select at least one tag"

  let right = els:
    it.add query_input.render
    el(PSearchInfo, (message: message))
    el(FilterTags, (query_input: query_input))

  let right_down = els:
    el(Warns, ())

  let view =
    el(PApp, ( # App
      show_block_separator: true,
      title: "Filter", title_hint: "",
      right: right, right_down: right_down
    )):
      for blk in blocks: # Blocks
        let context = RenderContext.init(blk.doc, blk.doc.space.id)
        let blk_link = build_el(PIconLink, (icon: "link", url: blk.short_url))
        el(PBlock, (blk: blk, context: context, controls: @[blk_link], hover: false))

  view.window_title "Filter"
  view