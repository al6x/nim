import system except find
import basem, jsonm
import ../serverm, ../helpersm, ../commandsm, ../fs_storage
{.experimental: "code_reordering".}


# State --------------------------------------------------------------------------------------------
type
  Message = tuple[id: int, text: string]
  State = object
    messages:  seq[Message]
    add_text:  string
    edit_form: Option[Message]
    next_id:   int

proc init*(_: type[State]): State = discard

proc load*(_: type[State], id: string): State =
  storage()[id]

proc save*(state: State, id: string): void =
  storage()[id] = state


# Templates ----------------------------------------------------------------------------------------
proc EditFormEl(message: Message): string =
  let update = action("update", (id: message.id), true)
  let cancel = action("cancel_edit")
  fmt"""
    <div id={message.id}>
      <form class="edit_form">
        <textarea name="update_text">{message.text.escape_html}</textarea>
        <button on_click={update}>Update</button>
        <button on_click={cancel}>Cancel</button>
      </form>
    </div>
  """

proc MessageEl(message: Message): string =
  let edit    = action("edit", (id: message.id))
  let delete  = action("delete", (id: message.id))
  fmt"""
    <div id={message.id} class="message flashable">
      <span>{message.text.escape_html}</span>
      <button on_click={delete}>Delete</button>
      <button on_click={edit}>Edit</button>
    </div>
  """

proc AppEl(state: State): string =
  let edit_form = state.edit_form
  proc ShowOrEditEl(message: Message): string =
    if edit_form.is_present and edit_form.get.id == message.id:
      EditFormEl(message)
    else:
      MessageEl(message)

  fmt"""
    <div id="app">
      <div id="messages">
        {state.messages.map(ShowOrEditEl).join("\n")}
      </div>
      <br/>
      <form class="add_form">
        <textarea name="add_text" placeholder="Write something...">{state.add_text}</textarea>
        <button on_click={action("add", true)}>Add</button>
      </form>
    </div>
  """

proc PageEl(server: Server, req: Request, state: State): string =
  fmt"""
    <html>
      <head>
        <link rel="stylesheet" href="{server.asset_path("/twitter.css")}">
      </head>
      <body>
        {AppEl(state)}

        {server.base_assets(req)}
      </body>
    </html>
  """


# Behavior -----------------------------------------------------------------------------------------
var server = Server.init(ServerConfig.init(
  assets_file_paths = @["./web/examples"])
)

server.get("/", proc (req: Request): auto =
  let state = State.load(req.user_token)
  respond PageEl(server, req, state)
)

State.on("add", proc (state: var State, data: tuple[add_text: string]): void =
  state.messages.add((state.next_id, data.add_text))
  state.next_id += 1
  state.add_text = ""
)

State.on("delete", proc (state: var State, data: tuple[id: int]): void =
  state.messages.delete((message) => message.id == data.id)
)

State.on("edit", proc (state: var State, data: tuple[id: int]): void =
  let message = state.messages.find((message) => message.id == data.id).get
  state.edit_form = message.some
)

State.on("cancel_edit", proc (state: var State): void =
  state.edit_form = Message.none
)

State.on("update", proc (state: var State, data: tuple[id: int, update_text: string]): void =
  let i = state.messages.findi((message) => message.id == data.id).get
  state.messages[i].text = data.update_text
  state.edit_form = Message.none
)

server.run


# Helpers ------------------------------------------------------------------------------------------

proc on*[T](
  _: type[State], action: string, handler: proc(state: var State, input: T): void
): void =
  server.action(action, proc (req: Request): auto =
    var state = State.load(req.user_token)
    let input: T = req.data.to(T)
    handler(state, input)
    state.save(req.user_token)
    (update: AppEl(state))
  )

proc on*(
  _: type[State], action: string, handler: proc(state: var State): void
): void =
  server.action(action, proc (req: Request): auto =
    var state = State.load(req.user_token)
    handler(state)
    state.save(req.user_token)
    (update: AppEl(state))
  )

proc storage(): FsStorage[State] =
  FsStorage[State].init "./tmp/twitter"