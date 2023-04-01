# nim c -r web/examples/counter.nim

import basem, jsonm
import ../serverm, ../helpersm, ../commandsm, ../fs_storage
import os, locks

var counter_lock: Lock
counter_lock.init_lock

var counter {.guard: counter_lock.} = 0

proc Counter(counter: int): string = fmt"""
  <span id="counter">
    Counter = {counter} <button on_click={action("/increment")}>+</button>
  </span>
"""

proc Page(req: Request, counter: int): string = fmt"""
<html>
  <body>
    {Counter(counter)}

    {req.base_assets()}
  </body>
</html>
"""

var server = Server.init()

server.get("/", proc (req: Request): auto =
  with_lock counter_lock:
    return respond Page(req, counter)
)

server.action("increment", proc (req: Request): auto =
  with_lock counter_lock:
    counter += 1
    return (update: Counter(counter))
)

server.run