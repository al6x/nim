import system except find
import basem, jsonm
import ../serverm, ../helpersm, ../commandsm, ../fs_storage
import os
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
    <form>
      <textarea name="update_text">{message.text.escape_html}</textarea>
      <button on_click={update}>Update</button>
      <button on_click={cancel}>Cancel</button>
    </form>
  """

proc MessageEl(message: Message): string =
  let edit    = action("edit", (id: message.id))
  let delete  = action("delete", (id: message.id))
  fmt"""
    <div>
      <span>{message.text.escape_html}</span>
      <button on_click={edit}>Edit</button>
      <button on_click={delete}>Delete</button>
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
      <form>
        <textarea name="add_text">{state.add_text}</textarea>
        <button on_click={action("add", true)}>Add</button>
      </form>
    </div>
  """

proc PageEl(req: Request, state: State): string =
  fmt"""
    <html>
      <body>
        {AppEl(state)}

        {req.base_assets()}
      </body>
    </html>
  """


# Behavior -----------------------------------------------------------------------------------------
var server = Server.init()

server.get("/", proc (req: Request): auto =
  let state = State.load(req.user_token)
  respond PageEl(req, state)
)

State.on("add", proc (state: var State, data: tuple[add_text: string]): void =
  state.messages.add((state.next_id, data.add_text))
  state.next_id += 1
  state.add_text = ""
)

State.on("delete", proc (state: var State, data: tuple[id: int]): void =
  state.messages = state.messages.filter((message) => message.id != data.id)
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
  _: type[State], action: string, handler: proc(state: var State, input: T): void {.gcsafe.}
): void =
  server.action(action, proc (req: Request): auto =
    var state = State.load(req.user_token)
    let input: T = req.data.to(T)
    handler(state, input)
    state.save(req.user_token)
    (update: AppEl(state))
  )

proc on*(
  _: type[State], action: string, handler: proc(state: var State): void {.gcsafe.}
): void =
  server.action(action, proc (req: Request): auto =
    var state = State.load(req.user_token)
    handler(state)
    state.save(req.user_token)
    (update: AppEl(state))
  )


proc storage(): FsStorage[State] =
  FsStorage[State].init "./tmp/twitter"