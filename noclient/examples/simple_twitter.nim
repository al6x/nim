import system except find
import basem, jsonm
import ../web/serverm, ../web/helpersm, ./helpersm, ../web/fs_storage
import os
{.experimental: "code_reordering".}


# State --------------------------------------------------------------------------------------------
type
  State = object
    messages:  seq[string]
    add_text:  string

proc init*(_: type[State]): State = discard

proc load*(_: type[State], id: string): State =
  storage()[id]

proc save*(state: State, id: string): void =
  storage()[id] = state


# Templates ----------------------------------------------------------------------------------------
proc MessageEl(message: string): string =
  fmt"""
    <div class="message">{message.escape_html}</div>
  """

proc AppEl(state: State): string =
  fmt"""
    <div id="app">
      <div id="messages">
        {state.messages.map(MessageEl).join("\n")}
      </div>
      <br/>
      <form class="add_form">
        <textarea name="add_text" placeholder="Write something...">{state.add_text}</textarea>
        <button on_click={action("add", true)} class="primary">Add</button>
      </form>
    </div>
  """

proc PageEl(server: Server, req: Request, state: State): string =
  fmt"""
    <html>
      <head>
        <link rel="stylesheet" href="{server.asset_path("/examples/twitter.css")}">
      </head>
      <body>
        {AppEl(state)}

        {server.base_assets(req)}
      </body>
    </html>
  """


# Behavior -----------------------------------------------------------------------------------------
var server = Server.init(ServerConfig.init(
  assets_file_paths = @["./noclient"])
)

server.get("/", proc (req: Request): auto =
  let state = State.load(req.user_token)
  respond PageEl(server, req, state)
)

State.on("add", proc (state: var State, data: tuple[add_text: string]): void =
  state.messages.add(data.add_text)
  state.add_text = ""
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

proc storage(): FsStorage[State] =
  FsStorage[State].init "./tmp/simple_twitter"