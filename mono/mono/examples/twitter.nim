import base, mono/[core, http], ext/persistence, std/os

# Model --------------------------------------------------------------------------------------------
type
  Message = ref object
    text: string
  Db = ref object
    messages: seq[Message]

proc save(db: Db) =
  db.write_to "./tmp/twitter.json"

# UI -----------------------------------------------------------------------------------------------
type TwitterView = ref object of Component
  db:   Db
  add:  string
  edit: Option[(int, string)]

proc render(self: TwitterView): El =
  proc add =
    if self.add.is_empty: return
    self.db.messages.add(Message(text: self.add)); self.db.save
    self.add = "";

  proc update =
    let (i, text) = self.edit.get
    self.db.messages[i].text = text; self.db.save
    self.edit.clear

  proc delete(i: int): auto =
    proc = self.db.messages.delete(i); self.db.save

  el("app", (window_title: fmt"{self.db.messages.len} messages")):
    for i, message in self.db.messages:
      capt i, message:
        if self.edit.is_some and i == self.edit.get[0]:
          el"form.edit_form":
            el("textarea", it.bind_to(self.edit.get[1]))
            el("button", (text: "Cancel"), it.on_click(proc = self.edit.clear))
            el("button.primary", (text: "Update"), it.on_click(update))
        else:
          el"message":
            el("", (text: message.text))
            el("button", (text: "Delete"), it.on_click(delete(i)))
            el("button", (text: "Edit"), it.on_click(proc = self.edit = (i, message.text).some))
    el"form.add_form":
      el("textarea", (placeholder: "Write something..."), it.bind_to(self.add))
      el("button.primary", (text: "Add"), it.on_click(add))

# Deployment ---------------------------------------------------------------------------------------
when is_main_module:
  let db = Db.read_from("./tmp/twitter.json").get(() => Db(messages: @[
    "MSFT stock went UP, time to buy!",
    "SHELL stock went DOWN, time to sell!",
    "Buy top, sell bottom, that's the wisdom!"
  ].mapit(Message(text: it))))

  let asset_path = current_source_path().parent_dir.absolute_path
  run_http_server((() => TwitterView(db: db)), asset_paths = @[asset_path], styles = @["/assets/twitter.css"])