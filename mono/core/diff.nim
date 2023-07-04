import base, ./mono_el

type
  Diff* = JsonNode

# types --------------------------------------------------------------------------------------------
proc replace          *(id: seq[int], el: El            ): Diff = %["replace", id, el]
proc add_children     *(id: seq[int], els: seq[El]      ): Diff = %["add_children", id, els]
proc set_children_len *(id: seq[int], len: int          ): Diff = %["set_children_len", id, len]
proc set_attrs        *(id: seq[int], attrs: JsonNode   ): Diff = %["set_attrs", id, attrs.to_json]
proc del_attrs        *(id: seq[int], attrs: seq[string]): Diff = %["del_attrs", id, attrs.to_json]
proc set_text         *(id: seq[int], text: string      ): Diff = %["set_text", id, text]
proc set_html         *(id: seq[int], html: string      ): Diff = %["set_html", id, html]

# diff ---------------------------------------------------------------------------------------------
proc has_single_content_child(el: El): bool =
  # it's possible to support el.list, but it's very rarely needed and not worth to add complexity
  assert el.kind != ElKind.list, "el.list not supported"
  el.children.len == 1 and el.children[0].kind in [ElKind.text, ElKind.html]

proc get_single_content_child(el: El): El =
  assert el.kind == ElKind.el and el.children.len == 1 and el.children[0].kind in [ElKind.text, ElKind.html]
  el.children[0]

proc same_len_and_kind(a, b: seq[El]): bool =
  if a.len != b.len: return false
  for i, ai in a:
    if ai.kind != b[i].kind: return false
  true

proc diff(id: seq[int], oel, nel: El, diffs: var seq[Diff]) =
  assert oel.kind == ElKind.el and nel.kind == ElKind.el, "root element should be of kind el"

  if oel.tag != nel.tag: # tag
    diffs.add replace(id, nel)
    return

  if oel.attrs != nel.attrs: # attrs
    var set_attrs = newJObject()
    for k, v in nel.attrs:
      if k notin oel.attrs or v != oel.attrs[k]: set_attrs[k] = v
    unless set_attrs.is_empty: diffs.add set_attrs(id, set_attrs)

    var del_attrs: seq[string]
    for k, _ in oel.attrs:
      if k notin nel.attrs:
        del_attrs.add k
    unless del_attrs.is_empty: diffs.add del_attrs(id, del_attrs)

  # children
  if oel.has_single_content_child or nel.has_single_content_child:
    # text, html children
    if same_len_and_kind(oel.children, nel.children):
      # Updating text, html
      let ocontent = oel.get_single_content_child; let ncontent = nel.get_single_content_child
      case ncontent.kind
      of ElKind.text:
        assert ocontent.kind == ElKind.text
        if ocontent.text_data != ncontent.text_data:
          diffs.add set_text(id, ncontent.text_data)
      of ElKind.html:
        assert ocontent.kind == ElKind.html
        if ocontent.html_data != ncontent.html_data:
          diffs.add set_html(id, ncontent.html_data)
      else:
        throw"invalid el kind"
    else:
      # Structure changed, replacing with parent
      diffs.add replace(id, nel)
  else:
    # el children
    var add_children: seq[El]
    # Expanding list kind elements in children
    let (nchildren, ochildren) = (nel.children.flatten, oel.children.flatten)
    for i, nchild in nchildren:
      assert nchild.kind == ElKind.el, "mixed children content not supported"
      if i < ochildren.len:
        let ochild = ochildren[i]
        assert ochild.kind == ElKind.el, "mixed children content not supported"
        diff(id & [i], ochild, nchild, diffs)
      else:
        add_children.add nchild
    unless add_children.is_empty: diffs.add add_children(id, add_children)

    if nchildren.len < ochildren.len:
      for ochild in ochildren: assert ochild.kind == ElKind.el, "mixed children content not supported"
      diffs.add set_children_len(id, nchildren.len)

proc diff*(id: openarray[int], oel, nel: El): seq[Diff] =
  diff(id.to_seq, oel, nel, result)