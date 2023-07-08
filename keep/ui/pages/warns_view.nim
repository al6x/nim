import base, mono/core
import ../../model, ../helpers, ../palette as pl, ../location

type WarnsView* = ref object of Component

proc render*(self: WarnsView): El =
  var rows: seq[seq[El]]
  for record in db.records_with_warns_cached:
    rows.add @[
      el(PLink, (text: record.id, link: record.url)),
      el(PWarnings, (warns: record.warns.mapit((it, ""))))
    ]

  let view =
    el(PApp, (title: "Warns".some)):
      pblock_layout "message":
        if rows.is_empty:
          el(PMessage, (text: "No warns"))
        else:
          el(PTable, (rows: rows))

  view.window_title "Warns"
  view