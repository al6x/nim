import base, mono/core
import ../../model, ../palette, ./query_input

proc FilterTags*(query_input: QueryInput): El =
  let counts = db.tags_stats_cached
  let tags = counts.keys.to_seq.sort
  let filter = query_input.filter

  proc incl_or_excl_tag(tag: string): proc(e: ClickEvent) =
    proc(e: ClickEvent) =
      var f = filter
      f.excl.deleteit(it == tag); f.incl.deleteit(it == tag)
      if shift in e.special_keys: f.excl = (f.excl & @[tag]).sort
      else:                       f.incl = (f.incl & @[tag]).sort
      query_input.set_query f.to_s

  proc deselect_tag(tag: string): proc(e: ClickEvent) =
    proc(e: ClickEvent) =
      var f = filter
      let excl = tag in f.incl and shift in e.special_keys
      f.excl.deleteit(it == tag); f.incl.deleteit(it == tag)
      if excl: f.excl = (f.excl & @[tag]).sort
      query_input.set_query f.to_s

  let no_selected = filter.incl.is_empty and filter.excl.is_empty
  el(PTags, ()):
    for tag in tags:
      capt tag:
        let title = counts[tag].to_s
        if   tag in filter.incl:
          alter_el(el(PTag, (text: tag, style: included, title: title))):
            it.attr("href", "#")
            it.on_click deselect_tag(tag)
        elif tag in filter.excl:
          alter_el(el(PTag, (text: tag, style: excluded, title: title))):
            it.attr("href", "#")
            it.on_click deselect_tag(tag)
        elif no_selected:
          alter_el(el(PTag, (text: tag, style: normal, title: title))):
            it.attr("href", "#")
            it.on_click incl_or_excl_tag(tag)
        else:
          alter_el(el(PTag, (text: tag, style: ignored, title: title))):
            it.attr("href", "#")
            it.on_click incl_or_excl_tag(tag)