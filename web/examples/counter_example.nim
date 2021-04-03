# nim c -r web/examples/counter_example.nim

import basem, jsonm
import ../serverm, ../helpersm, ../commandsm, ../fs_sessionsm
import os

type State = object
  count:     int
  set_count: int

proc init*(_: type[State]): State = discard

proc Counter(count: int): string = fmt"""
  <span id="counter">
    Counter = {count} <button on_click={call("/increment")}>+</button>
  </span>
"""

proc Form(count: int): string = fmt"""
  <form id="setter">
    <input name="count" type="text" value="{count}">
    <button on_click={call("/set", true)}>Set</button>
  </form>
"""

proc Page(req: Request, state: State): string = fmt"""
<html>
  <body>
    {Counter(state.count)}
    <br/>
    {Form(state.set_count)}

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

  respond Page(req, state)
)

server.action("increment", proc (req: Request): auto =
  let sessions = sessions()
  var state = sessions[req.session_token]
  state.count += 1
  sessions[req.session_token] = state

  (update: Counter(state.count), flash: true)
)

server.action("set", proc (req: Request): auto =
  let count = req["count"].parse_int

  let sessions = sessions()
  var state = sessions[req.session_token]
  state.count     = count
  state.set_count = count
  sessions[req.session_token] = state

  (update: [Counter(state.count), Form(state.set_count)], flash: true)
)

server.run