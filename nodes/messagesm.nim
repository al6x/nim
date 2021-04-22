import asyncdispatch, options, os, strformat, tables
import ./supportm, ./nodem
from ./messages_asyncm as ma import nil

export nodem

{.experimental: "code_reordering".}

# receive ------------------------------------------------------------------------------------------
proc receive*(name: Node): string =
  # Auto-reconnects and waits untill it gets the message
  try:
    wait_for ma.receive(name)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't receive from {name}, {e.msg.clean_async_error}"


# send ---------------------------------------------------------------------------------------------
proc send*(name: Node, message: string, wait = true): void =
  # If wait is true waiting for response
  try:
    if wait: wait_for     ma.send(name, message)
    else:    async_ignore ma.emit(name, message)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't send to {name}, {e.msg.clean_async_error}"


# call ---------------------------------------------------------------------------------------------
proc call*(name: Node, message: string): string =
  # Send message and waits for reply
  try:
    wait_for ma.call(name, message)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't call {name}, {e.msg.clean_async_error}"


# on_receive ---------------------------------------------------------------------------------------
type MessageHandler* = proc (message: string): Option[string]

proc on_receive*(name: Node, handler: MessageHandler) =
  proc async_handler(message: string): Future[Option[string]] {.async.} =
    return handler(message)
  ma.on_receive(name, async_handler)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let example = Node("example")
  nodes_names[example] = "tcp://localhost:4000"

  proc server =
    echo "server started"
    proc handle (message: string): Option[string] =
      case message
      of "quit":    # Hanldes `send`, without reply
        echo "quitting"
        quit()
      of "process": # Handles `call`, with reply
        echo "processing"
        return "some result".some
      else:
        throw fmt"unknown message {message}"
    example.on_receive(handle)

  proc client =
    echo "client started"
    let server = "tcp://localhost:4000"
    echo example.call("process")
    example.send "quit"

  case param_str(1)
  of "server": server()
  of "client": client()
  else:        echo "wrong argument, expected client or server"