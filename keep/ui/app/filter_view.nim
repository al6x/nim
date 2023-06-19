import base, mono/[core, http]
import ../../model, ../../render/blocks, ./helpers, ../palette as pl, ./location

type FilterView* = ref object of Component
  filter*: Filter

proc render*(self: FilterView): El =
  let blocks = db.filter_blocks(self.filter).to_seq

  let all_tags = db.ntags_cached.keys.map(decode_tag)
  let right = els:
    # el(PTags, (tags: all_tags.with_path(context)))
    discard

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
  view