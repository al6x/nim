import base, mono/[core, http], ext/persistence, std/os

# Model --------------------------------------------------------------------------------------------
type
  Message = ref object
    text: string
  Db = ref object
    messages: seq[Message]

proc save(db: Db) =
  db.write_to "./tmp/twitter.json"

# While it's possible to pass `db` explicitly to the Component, I prefer to pass it via context.
var db* {.threadvar.}: Db

# UI -----------------------------------------------------------------------------------------------
type MessageView = ref object of Component
  i:       int
  message: Message
  # Components are statefull, the state of `edit` will be preserved between requests
  edit:    Option[string]

proc render(self: MessageView): El =
  proc update =
    db.messages[self.i].text = self.edit.get; db.save
    self.edit.clear

  proc delete(i: int): auto =
    proc = db.messages.delete(i); db.save

  if self.edit.is_some:
    el"form.edit_form": # Class shortcut, the `.edit_form` will be set as class.
      el("textarea", it.bind_to(self.edit)) # bidirecectional binding inputs and variables
      el("button", (text: "Cancel"), it.on_click(proc = self.edit.clear))
      el("button.primary", (text: "Update"), it.on_click(update))
  else:
    el"message":
      el("", (text: self.message.text))
      el("button", (text: "Delete"), it.on_click(delete(self.i)))
      el("button", (text: "Edit"), it.on_click(proc = self.edit = self.message.text.some))

type AddForm = ref object of Component
  add: string

proc render(self: AddForm): El =
  proc add =
    if self.add.is_empty: return
    db.messages.add(Message(text: self.add)); db.save
    self.add = "";

  el"form.add_form":
    el("textarea", (placeholder: "Write something..."), it.bind_to(self.add))
    el("button.primary", (text: "Add"), it.on_click(add))


type TwitterView = ref object of Component

proc render(self: TwitterView): El =
  el"app": # Initial page will also have
    it.window_title fmt"{db.messages.len} messages" # Title will be changed dynamically
    for i, message in db.messages:
      self.el(MessageView, i, (i: i, message: message)) # Using components
    self.el(AddForm, ())

# Deployment ---------------------------------------------------------------------------------------
when is_main_module:
  # Model could be shared, UI will be updated with changes, open multiple Browsers to see
  db = Db.read_from("./tmp/twitter.json").get(() => Db(messages: @[
    "MSFT stock went UP, time to buy!",
    "SHELL stock went DOWN, time to sell!",
    "Buy top, sell bottom, that's the wisdom!"
  ].mapit(Message(text: it))))

  let asset_path = current_source_path().parent_dir.absolute_path
  # The initial HTML page would have full HTML content, good for SEO
  run_http_server((() => TwitterView()), asset_paths = @[asset_path], styles = @["/assets/twitter.css"])