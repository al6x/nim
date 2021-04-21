import asyncdispatch, options, os
from ./net_asyncm as net_async import nil

{.experimental: "code_reordering".}

# receive ------------------------------------------------------------------------------------------
proc receive*(url: string): string =
  # Auto-reconnects and waits untill it gets the message
  wait_for net_async.receive(url)


# send ---------------------------------------------------------------------------------------------
proc send*(url: string, message: string): void =
  wait_for net_async.send(url, message)


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


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let address = "tcp://localhost:4000"

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
    receive(address, handle)

  proc client =
    echo "client started"
    echo address.call("process")
    address.emit "quit"
    wait_for sleep_async 10 # Otherwise program quit immediatelly and emit won't be delivered

  case param_str(1)
  of "server": server()
  of "client": client()
  else:        echo "wrong argument, expected client or server"