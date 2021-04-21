import asyncdispatch, options, os
from ./net_asyncm as net_async import nil

{.experimental: "code_reordering".}

# receive ------------------------------------------------------------------------------------------
proc receive*(url: string): string =
  # Auto-reconnects and waits untill it gets the message
  wait_for net_async.receive(url)


# send ---------------------------------------------------------------------------------------------
proc send*(url: string, message: string, wait = true): void =
  # If wait is true waiting for response
  if wait: wait_for     net_async.send(url, message)
  else:    async_ignore net_async.emit(url, message)


# emit ---------------------------------------------------------------------------------------------
proc emit*(url: string, message: string): void =
  # Don't wait till message is delivered and ignores if it's success or fail.
  async_check net_async.emit(url, message)


# call ---------------------------------------------------------------------------------------------
proc call*(url: string, message: string): string =
  # Send message and waits for reply
  wait_for net_async.call(url, message)


# receive ------------------------------------------------------------------------------------------
type MessageHandler* = proc (message: string): Option[string]

proc receive*(url: string, handler: MessageHandler) =
  proc async_handler(message: string): Future[Option[string]] {.async.} =
    return handler(message)
  net_async.receive(url, async_handler)


# async_ignore -------------------------------------------------------------------------------------
proc ignore_future[T](future: Future[T]): Future[void] {.async.} =
  try:    await future
  except: discard
proc async_ignore[T](future: Future[T]) =
  async_check ignore_future(future)


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
        raise new_exception(Exception, "unknown message" & "message")
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