import base, mono/core
import ../../model, ../helpers, ../palette as pl, ../location

type WarnsView* = ref object of Component

proc render*(self: WarnsView): El =
  var rows: seq[seq[El]]
  for (sid, did) in db.docs_with_warns:
    let doc = db.get(sid, did).get
    rows.add @[
      el(PLink, (text: doc.title.if_empty(doc.id), link: doc_url(sid, did))),
      el(PWarnings, (warns: doc.nwarns.mapit((it, ""))))
    ]

  let view =
    el(PApp, (title: "Warns")):
      pblock_layout "message":
        if rows.is_empty:
          el(PMessage, (text: "No warns"))
        else:
          el(PTable, (rows: rows))

  view.window_title "Warns"
  view