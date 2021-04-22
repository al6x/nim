import asyncdispatch, options, os, strformat, re
from ./net_asyncm as net_async import nil

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
proc receive*(url: string): string =
  # Auto-reconnects and waits untill it gets the message
  try:
    wait_for net_async.receive(url)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't receive from {url}, {e.msg.clean_async_error}"


# send ---------------------------------------------------------------------------------------------
proc send*(url: string, message: string, wait = true): void =
  # If wait is true waiting for response
  try:
    if wait: wait_for     net_async.send(url, message)
    else:    async_ignore net_async.emit(url, message)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't send to {url}, {e.msg.clean_async_error}"


# call ---------------------------------------------------------------------------------------------
proc call*(url: string, message: string): string =
  # Send message and waits for reply
  try:
    wait_for net_async.call(url, message)
  except Exception as e:
    # Higher level messages and getting rid of messy async stack trace
    throw fmt"can't call {url}, {e.msg.clean_async_error}"


# receive ------------------------------------------------------------------------------------------
type MessageHandler* = proc (message: string): Option[string]

proc receive*(url: string, handler: MessageHandler) =
  proc async_handler(message: string): Future[Option[string]] {.async.} =
    return handler(message)
  net_async.receive(url, async_handler)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
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
    receive("tcp://localhost:4000", handle)

  proc client =
    echo "client started"
    let server = "tcp://localhost:4000"
    echo server.call("process")
    server.send "quit"

  case param_str(1)
  of "server": server()
  of "client": client()
  else:        echo "wrong argument, expected client or server"