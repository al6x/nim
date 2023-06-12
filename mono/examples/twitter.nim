import base, mono/[core, http], ext/persistence, std/os

# Model --------------------------------------------------------------------------------------------
type Message = ref object
  id:   int
  text: string

# DB -----------------------------------------------------------------------------------------------
type Db = ref object
  db_path:  string
  messages: seq[Message]

proc load(_: type[Db], db_path: string, default = (() => seq[Message].init)): Db =
  let messages = seq[Message].read_from(db_path).get(default)
  Db(db_path: db_path, messages: messages)

proc save(self: Db) =
  self.messages.write_to self.db_path

# UI -----------------------------------------------------------------------------------------------
type TwitterView = ref object of Component
  db:   Db
  add:  string
  edit: Option[Message]

proc render(self: TwitterView): El =
  let db = self.db
  proc add =
    unless self.add.is_empty:
      let id = db.messages.find_max((m) => m.id).id + 1
      db.messages.add Message(id: id, text: self.add)
      self.add = ""
      db.save

  proc update =
    let edited = self.edit.get
    unless edited.text.is_empty:
      db.messages.fget_by(id, edited.id).get.text = edited.text
      self.edit.clear
      db.save

  proc delete(i: int): auto =
    proc =
      db.messages.delete(i)
      db.save

  proc edit(message: Message): auto =
    proc = self.edit = message.some

  el"app":
    for i, message in db.messages:
      if self.edit.is_some and message.id == self.edit.get.id:
        el"form.edit_form":
          el("textarea", it.bind_to(self.edit.get.text))
          el("button", (text: "Cancel"), it.on_click(proc = self.edit.clear))
          el("button.primary", (text: "Update"), it.on_click(update))
      else:
        el"message":
          el("message-text", (text: message.text))
          el("button", (text: "Delete"), it.on_click(delete(i)))
          el("button", (text: "Edit"), it.on_click(edit(message)))
    el"form.add_form":
      el("textarea", (placeholder: "Write something..."), it.bind_to(self.add))
      el("button.primary", (text: "Add"), it.on_click(add))

proc page(self: TwitterView, app_el: El): SafeHtml =
  # Feature: full static HTML, content and title for good SEO.
  default_html_page(app_el, styles = @["/assets/twitter.css"])

proc on_timer*(self: TwitterView): bool =
  true

# Deployment ---------------------------------------------------------------------------------------
when is_main_module:
  # Feature: model could be shared, UI will be updated with changes
  let db = Db.load("./tmp/twitter.json", () => @[
    Message(id: 1, text: "MSFT stock went UP, time to buy!"),
    Message(id: 2, text: "SHELL stock went DOWN, time to sell!"),
    Message(id: 2, text: "Buy top, sell bottom, that's the wisdom!"),
  ])

  let asset_path = current_source_path().parent_dir.absolute_path
  run_http_server((() => TwitterView(db: db)), asset_paths = @[asset_path])