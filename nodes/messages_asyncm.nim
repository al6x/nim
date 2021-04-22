import asyncdispatch, strutils, options, uri, tables, hashes, ./nodem, ./supportm
from asyncnet import AsyncSocket
from os import param_str

export nodem, asyncdispatch

{.experimental: "code_reordering".}

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


# receive ------------------------------------------------------------------------------------------
const delay_ms = 100
proc receive*(name: Node): Future[string] {.async.} =
  # Auto-reconnects and waits untill it gets the message
  var success = false
  try:
    # Handling connection errors and auto-reconnecting
    while true:
      let socket = block:
        let (is_error, error, socket) = await connect name
        if is_error:
          await sleep_async delay_ms
          continue
        socket
      let (is_error, is_closed, error, _, message) = await socket.receive_message
      if is_error or is_closed:
        await sleep_async delay_ms
        continue
      success = true
      return message
  finally:
    # Closing socket on any error, it will be auto-reconnected
    if not success: await disconnect(name)


# send ---------------------------------------------------------------------------------------------
proc send*(name: Node, message: string): Future[void] {.async.} =
  # Send message, if acknowledge without reply
  let (is_error, error, socket) = await connect(name)
  if is_error: throw error
  var success = false
  try:
    await socket.send_message(message)
    success = true
  finally:
    # Closing socket on any error, it will be auto-reconnected
    if not success: await disconnect(name)


# emit ---------------------------------------------------------------------------------------------
proc emit*(name: Node, message: string): Future[void] {.async.} =
  # Emit message without reply and don't check if it's delivered or not, never fails
  let (is_error, _, socket) = await connect(name)
  if not is_error:
    try:
      await socket.send_message(message)
    except:
      # Closing socket on any error, it will be auto-reconnected
      await disconnect(name)


# call ---------------------------------------------------------------------------------------------
proc call*(name: Node, message: string): Future[string] {.async.} =
  # Send message and waits for reply
  let socket = block:
    let (is_error, error, socket) = await connect(name)
    if is_error: throw error
    socket
  var success = false
  try:
    let id = next_id()
    await socket.send_message(message, id)
    let (is_error, is_closed, error, reply_id, reply) = await socket.receive_message
    if is_error: throw error
    if is_closed: throw "socket closed"
    if reply_id != id: throw "wrong reply id for call"
    success = true
    return reply
  finally:
    # Closing socket on any error, it will be auto-reconnected
    if not success: await disconnect(name)


# on_receive ---------------------------------------------------------------------------------------
type AsyncMessageHandler* = proc (message: string): Future[Option[string]]

proc on_receive*(name: Node, handler: AsyncMessageHandler) =
  async_check process(name, handler)
  run_forever()

proc process*(name: Node, handler: AsyncMessageHandler): Future[void] {.async.} =
  let (scheme, host, port) = parse_url name.to_url
  if scheme != "tcp": throw "only TCP supported"
  var server = asyncnet.new_async_socket()
  asyncnet.bind_addr(server, Port(port), host)
  asyncnet.listen(server)

  while true:
    let client = await asyncnet.accept(server)
    async_check process_client(client, handler)

proc process_client(client: AsyncSocket, handler: AsyncMessageHandler) {.async.} =
  try:
    while not asyncnet.is_closed(client):
      let (is_error, is_closed, error, message_id, message) = await client.receive_message
      if is_error: throw error
      if is_closed: break
      let reply = await handler(message)
      if reply.is_some:
        await send_message(client, reply.get, message_id)
  finally:
    # Ensuring socket is closed
    try:    asyncnet.close(client)
    except: discard


# autoconnect --------------------------------------------------------------------------------------
# Auto-connect for sockets, maybe also add auto-disconnect if it's not used for a while
var sockets: Table[string, AsyncSocket]
proc connect(name: Node): Future[tuple[is_error: bool, error: string, socket: AsyncSocket]] {.async.} =
  let url = name.to_url
  if url notin sockets:
    let (scheme, host, port) = url.parse_url
    if scheme != "tcp": throw "only TCP supported"
    var socket = asyncnet.new_async_socket()
    try:
      await asyncnet.connect(socket, host, Port(port))
    except Exception as e:
      return (true, e.msg, socket)
    sockets[url] = socket
  return (false, "", sockets[url])


# disconnect ---------------------------------------------------------------------------------------
proc disconnect*(name: Node): Future[void] {.async.} =
  let url = name.to_url
  if url in sockets:
    let socket = sockets[url]
    try:     asyncnet.close(socket)
    except:  discard
    finally: sockets.del url


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let example = Node("example")
  nodes_names[example] = "tcp://localhost:4000"

  proc server =
    echo "server started"
    proc handle (message: string): Future[Option[string]] {.async.} =
      case message
      of "quit":    # Hanldes `send`, without reply
        echo "quitting"
        quit()
      of "process": # Handles `call`, with reply
        echo "processing"
        return "some result".some
      else:
        throw "unknown message" & message
    example.on_receive(handle)

  proc client: Future[void] {.async.} =
    echo "client started"
    echo await example.call("process")
    await example.send "quit"

  case param_str(1)
  of "server": server()
  of "client": wait_for client()
  else:        echo "wrong argument, expected client or server"