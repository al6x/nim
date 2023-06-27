import base, ./mono_el

type
  Diff* = JsonNode
  ElAttrDel* = (string, ElAttrKind)

# Helpers ------------------------------------------------------------------------------------------
proc to_json_hook*(el: ElAttrVal | ElAttrDel): JsonNode =
  if el[1] == string_attr: el[0].to_json else: %[el[0], el[1]]

proc to_json_hook*(table: Table[string, ElAttrVal]): JsonNode =
  table.map((v) => v.to_json_hook).sort.to_json

proc to_json_hook*(delete_attrs: seq[ElAttrDel]): JsonNode =
  delete_attrs.sort((v) => v[0]).map((v) => v.to_json_hook).to_json

# types --------------------------------------------------------------------------------------------
proc replace          *(id: seq[int], el: El                         ): Diff = %["replace", id, el.to_html]
proc add_children     *(id: seq[int], els: seq[El]                   ): Diff = %["add_children", id, els.mapit(it.to_html)]
proc set_children_len *(id: seq[int], len: int                       ): Diff = %["set_children_len", id, len]
proc set_attrs        *(id: seq[int], attrs: Table[string, ElAttrVal]): Diff = %["set_attrs", id, attrs.to_json]
proc del_attrs        *(id: seq[int], attrs: seq[ElAttrDel]          ): Diff = %["del_attrs", id, attrs.to_json]
proc set_text         *(id: seq[int], text: string                   ): Diff = %["set_text", id, text]
proc set_html         *(id: seq[int], html: string                   ): Diff = %["set_html", id, html]

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
  assert oel.kind == ElKind.el and nel.kind == ElKind.el, "root should be el"

  if oel.tag != nel.tag: # tag
    diffs.add replace(id, nel)
    return

  var oel = oel; var nel = nel
  if oel.attrs != nel.attrs: # attrs
    # Normalization needed only if attrs has been changed
    # Normalization may change content, for example replace attr value into html content for textarea,
    # so oel and nel needs to be replaced with normalized versions.
    let oel_norm = oel.normalize true # (oel_norm, oattrs) could be cached
    oel = oel_norm[0]; let oattrs = oel_norm[1]

    let nel_norm = nel.normalize true
    nel = nel_norm[0]; let nattrs = nel_norm[1]

    var set_attrs: Table[string, ElAttrVal]
    for k, v in nattrs:
      if k notin oattrs or v != oattrs[k]: set_attrs[k] = v
    unless set_attrs.is_empty: diffs.add set_attrs(id, set_attrs)

    var del_attrs: seq[ElAttrDel]
    for k, v in oattrs:
      if k notin nattrs:
        del_attrs.add (k, v[1])
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
    let (nchildren, ochildren) = (nel.children.expand_children, oel.children.expand_children)
    for i, nchild in nchildren:
      assert nchild.kind == ElKind.el, "mixed children content not supported"
      if i < ochildren.len:
        let ochild = ochildren[i]
        assert ochild.kind == ElKind.el, "mixed children content not supported"
        diff(id & [i], ochild, nchild, diffs)
      else:
        add_children.add nchild
    unless add_children.is_empty: diffs.add add_children(id, add_children)

    if nel.children.len < oel.children.len:
      for ochild in oel.children: assert ochild.kind == ElKind.el, "mixed children content not supported"
      diffs.add set_children_len(id, nel.children.len)

proc diff*(id: openarray[int], oel, nel: El): seq[Diff] =
  diff(id.to_seq, oel, nel, result)