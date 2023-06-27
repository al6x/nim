import base, mono/core
import ../../model, ../palette, ./query_input

proc FilterTags*(query_input: QueryInput): El =
  let tags = db.ntags_cached.keys.map(decode_tag).sortit(it.to_lower)
  let filter = query_input.filter

  proc incl_or_excl_tag(tag: int): proc(e: ClickEvent) =
    proc(e: ClickEvent) =
      var f = filter
      f.excl.deleteit(it == tag); f.incl.deleteit(it == tag)
      if shift in e.special_keys: f.excl = (f.excl & @[tag]).sort
      else:                       f.incl = (f.incl & @[tag]).sort
      query_input.set_query f.to_s

  proc deselect_tag(tag: int): proc(e: ClickEvent) =
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