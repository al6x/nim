import basem, jsonm
import ../serverm, ../helpersm, ../commandsm, ../fs_sessionsm
import os

type State = object
  count: int

proc init*(_: type[State]): State = discard

proc Counter(count: int): string = fmt"""
  <span id="value">
    Counter = {count} <button on_click={call("/increment")}>+</button>
  </span>
"""

proc Page(req: Request, count: int): string = fmt"""
<html>
  <body>
    {Counter(count)}

    {req.base_assets()}
  </body>
</html>
"""

proc sessions(): FsSessions[State] =
  FsSessions[State].init "./tmp/sessions"

var server = Server.init()

server.get("/", proc (req: Request): auto =
  let sessions = sessions()
  let state = sessions[req.session_token]

  respond Page(req, state.count)
)

server.action("increment", proc (req: Request): auto =
  let sessions = sessions()
  var state = sessions[req.session_token]
  state.count += 1
  sessions[req.session_token] = state

  (update: Counter(state.count), flash: true)
)

server.run