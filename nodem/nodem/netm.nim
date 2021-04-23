import asyncdispatch, strutils, strformat, options, uri, tables, hashes, times
from net import OptReuseAddr
from asyncnet import AsyncSocket
from os import param_str
import ./addressm, ./supportm

export addressm, asyncdispatch


# autoconnect --------------------------------------------------------------------------------------
var sockets: Table[string, AsyncSocket]
proc connect(
  address: Address
): Future[tuple[is_error: bool, error: string, socket: Option[AsyncSocket]]] {.async.} =
  # Auto-connect for sockets, if not available wait's till connection would be available with timeout,
  # maybe also add auto-disconnect if it's not used for a while

  let (url, timeout_ms) = address.get
  if timeout_ms <= 0: throw "tiemout should be greather than zero"
  if url notin sockets:
    let (scheme, host, port, path) = url.parse_url
    if scheme != "tcp": throw "only TCP supported"
    if path != "": throw "wrong path"

    # Waiting for timeout
    let tic = timer_ms()
    while true:
      var socket = asyncnet.new_async_socket()
      try:
        let left_ms = timeout_ms - tic()
        if left_ms > 0:
          if await asyncnet.connect(socket, host, Port(port)).with_timeout(left_ms):
            sockets[url] = socket
            break
        else:
          await asyncnet.connect(socket, host, Port(port))
          sockets[url] = socket
          break
      except Exception as e:
        try:    asyncnet.close(socket)
        except: discard

      let delay_time_ms = 20
      let left_ms = timeout_ms - tic()
      if left_ms <= delay_time_ms:
        return (true, "Timed out, connection closed", AsyncSocket.none)
      else:
        await sleep_async delay_time_ms

  return (false, "", sockets[url].some)


# disconnect ---------------------------------------------------------------------------------------
proc disconnect*(address: Address): Future[void] {.async.} =
  let (url, _) = address.get
  if url in sockets:
    let socket = sockets[url]
    try:     asyncnet.close(socket)
    except:  discard
    finally: sockets.del url


# send_message, receive_message --------------------------------------------------------------------
var id_counter: int64 = 0
proc next_id: int64 = id_counter += 1

proc send_message(socket: AsyncSocket, message: string, message_id = next_id()): Future[void] {.async.} =
  await asyncnet.send(socket, ($(message.len.int8)).align_left(8))
  await asyncnet.send(socket, ($message_id).align_left(64))
  await asyncnet.send(socket, message)

proc receive_message(
  socket: AsyncSocket
): Future[tuple[is_error: bool, is_closed: bool, error: string, message_id: int, message: string]] {.async.} =
  template return_error(error: string) = return (true, true, error, -1, "")

  let message_length_s = await asyncnet.recv(socket, 8)
  if message_length_s == "": return (false, true, "", -1, "") # Socket disconnected
  if message_length_s.len != 8: return_error("socket error, wrong size for message length")
  let message_length = message_length_s.replace(" ", "").parse_int

  let message_id_s = await asyncnet.recv(socket, 64)
  if message_id_s.len != 64: return_error("socket error, wrong size for message_id")
  let message_id = message_id_s.replace(" ", "").parse_int

  let message = await asyncnet.recv(socket, message_length)
  if message.len != message_length: return_error("socket error, wrong size for message")
  return (false, false, "", message_id, message)


# send ---------------------------------------------------------------------------------------------
proc send*(address: Address, message: string): Future[void] {.async.} =
  # Send message, if acknowledge without reply
  let (_, timeout_ms) = address.get
  if timeout_ms <= 0: throw "tiemout should be greather than zero"
  let tic = timer_ms()
  let (is_error, error, socket) = await connect(address)
  if is_error: throw error
  var success = false
  try:
    let left_ms = timeout_ms - tic() # some time could be used by `connect`
    if left_ms <= 0: throw "send timed out"
    if not await socket.get.send_message(message).with_timeout(left_ms):
      throw "send timed out"
    success = true
  finally:
    # Closing socket on any error, it will be auto-reconnected
    if not success: await disconnect(address)


# call ---------------------------------------------------------------------------------------------
proc call*(address: Address, message: string): Future[string] {.async.} =
  # Send message and waits for reply
  let (_, timeout_ms) = address.get
  if timeout_ms <= 0: throw "tiemout should be greather than zero"

  let tic = timer_ms()
  let socket = block:
    let (is_error, error, socket) = await connect(address)
    if is_error: throw error
    socket

  var success = false
  try:
    let id = next_id()

    # Sending
    var left_ms = timeout_ms - tic() # some time could be used by `connect`
    if left_ms <= 0: throw "send timed out"
    if not await socket.get.send_message(message, id).with_timeout(left_ms):
      throw "send timed out"

    # Receiving
    left_ms = timeout_ms - tic()
    if left_ms <= 0: throw "receive timed out"
    let receivedf = socket.get.receive_message
    if not await receivedf.with_timeout(left_ms): throw "receive timed out"
    let (is_error, is_closed, error, reply_id, reply) = await receivedf

    if is_error: throw error
    if is_closed: throw "socket closed"
    if reply_id != id: throw "wrong reply id for call"
    success = true
    return reply
  finally:
    # Closing socket on any error, it will be auto-reconnected
    if not success: await disconnect(address)


# on_receive ---------------------------------------------------------------------------------------
type MessageHandler* = proc (message: string): Future[Option[string]]

proc process_client(client: AsyncSocket, handler: MessageHandler, timeout_ms: int) {.async.} =
  try:
    while not asyncnet.is_closed(client):
      let (is_error, is_closed, error, message_id, message) = await client.receive_message
      if is_error: throw error
      if is_closed: break
      let reply = await handler(message)
      if reply.is_some:
        if not await send_message(client, reply.get, message_id).with_timeout(timeout_ms):
          throw "replying to client is timed out"
  finally:
    # Ensuring socket is closed
    try:    asyncnet.close(client)
    except: discard

proc on_receive*(address: Address, handler: MessageHandler): Future[void] {.async.} =
  let (url, timeout_ms) = address.get
  if timeout_ms <= 0: throw "tiemout should be greather than zero"

  let (scheme, host, port, path) = parse_url url
  if scheme != "tcp": throw "only TCP supported"
  if path != "": throw "wrong path"
  var server = asyncnet.new_async_socket()
  asyncnet.set_sock_opt(server, OptReuseAddr, true)
  asyncnet.bind_addr(server, Port(port), host)
  asyncnet.listen(server)

  while true:
    let client = await asyncnet.accept(server)
    async_check process_client(client, handler, timeout_ms)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  # Two nodes working simultaneously and exchanging messages, there's no client or server
  let (a, b) = (Address("a"), Address("b"))

  proc start(self: Address, other: Address) =
    proc log(msg: string) = echo fmt"node {self} {msg}"

    proc on_self: Future[void] {.async.} =
      for _ in 1..3:
        log "heartbeat"
        let dstate = await other.call("state")
        log fmt"state of other: {dstate}"
        await sleep_async 1000
      await other.send("quit")

    proc on_receive(message: string): Future[Option[string]] {.async.} =
      case message
      of "state": # Handles `call`, with reply
        return fmt"{self} ok".some
      of "quit":    # Hanldes `send`, without reply
        log "quitting"
        quit()
      else:
        throw fmt"unknown message {message}"

    log "started"
    async_check on_self()
    async_check self.on_receive(on_receive)

  start(a, b)
  start(b, a)
  run_forever()

# receive ------------------------------------------------------------------------------------------
# const delay_ms = 100
# proc receive*(node: Address): Future[string] {.async.} =
#   # Auto-reconnects and waits untill it gets the message
#   var success = false
#   try:
#     # Handling connection errors and auto-reconnecting
#     while true:
#       let socket = block:
#         let (is_error, error, socket) = await connect node
#         if is_error:
#           await sleep_async delay_ms
#           continue
#         socket
#       let (is_error, is_closed, error, _, message) = await socket.receive_message
#       if is_error or is_closed:
#         await sleep_async delay_ms
#         continue
#       success = true
#       return message
#   finally:
#     # Closing socket on any error, it will be auto-reconnected
#     if not success: await disconnect(node)