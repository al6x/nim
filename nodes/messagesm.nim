import asyncdispatch, options, os, strformat, tables
import ./supportm, ./addressm
from ./amessagesm as msa import nil

export addressm

{.experimental: "code_reordering".}


# send ---------------------------------------------------------------------------------------------
proc send*(address: Address, message: string, wait = true): void =
  # If wait is true waiting for response
  try:
    if wait: wait_for     msa.send(address, message)
    else:    async_ignore msa.send(address, message)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't send to {address}, {e.msg.clean_async_error}"


# call ---------------------------------------------------------------------------------------------
proc call*(address: Address, message: string): string =
  # Send message and waits for reply
  try:
    wait_for msa.call(address, message)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't call {address}, {e.msg.clean_async_error}"


# on_receive ---------------------------------------------------------------------------------------
type MessageHandler* = proc (message: string): Option[string]

proc on_receive*(address: Address, handler: MessageHandler) =
  proc async_handler(message: string): Future[Option[string]] {.async.} =
    return handler(message)
  wait_for msa.on_receive(address, async_handler)
  run_forever()


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let example = Address("example")

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


# receive ------------------------------------------------------------------------------------------
# proc receive*(node: Address): string =
#   # Auto-reconnects and waits untill it gets the message
#   try:
#     wait_for msa.receive(node)
#   except Exception as e:
#     # Higher level messages and getting rid of messy async stack trace
#     throw fmt"can't receive from {node}, {e.msg.clean_async_error}"
