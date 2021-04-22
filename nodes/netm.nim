import asyncdispatch, options, os, strformat, re, tables, node_namem
from ./net_asyncm as net_async import nil

export node_namem

{.experimental: "code_reordering".}

# Helpers ------------------------------------------------------------------------------------------

proc ignore_future[T](future: Future[T]): Future[void] {.async.} =
  try:    await future
  except: discard
proc async_ignore[T](future: Future[T]) =
  async_check ignore_future(future)

template throw(message: string) = raise new_exception(Exception, message)

proc clean_async_error(error: string): string =
  error.replace(re"\nAsync traceback:[\s\S]+", "")


# receive ------------------------------------------------------------------------------------------
proc receive*(name: NodeName): string =
  # Auto-reconnects and waits untill it gets the message
  try:
    wait_for net_async.receive(name)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't receive from {name}, {e.msg.clean_async_error}"


# send ---------------------------------------------------------------------------------------------
proc send*(name: NodeName, message: string, wait = true): void =
  # If wait is true waiting for response
  try:
    if wait: wait_for     net_async.send(name, message)
    else:    async_ignore net_async.emit(name, message)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't send to {name}, {e.msg.clean_async_error}"


# call ---------------------------------------------------------------------------------------------
proc call*(name: NodeName, message: string): string =
  # Send message and waits for reply
  try:
    wait_for net_async.call(name, message)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't call {name}, {e.msg.clean_async_error}"


# on_receive ---------------------------------------------------------------------------------------
type MessageHandler* = proc (message: string): Option[string]

proc on_receive*(name: NodeName, handler: MessageHandler) =
  proc async_handler(message: string): Future[Option[string]] {.async.} =
    return handler(message)
  net_async.on_receive(name, async_handler)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let example = NodeName("example")
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