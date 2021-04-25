import ./useri

proc say_hi*(prefix: string): Future[string] {.async, nexport.} =
  # Nested circular call, calling `user_name` while user still waits for `say_hi`
  let name = await user_name()
  return prefix & " " & name

proc main: Future[void] {.async.} =
  # Node works as server, exposing `say_hi` and client asking for `user_name`
  while true:
    await sleep_async 1000
    try:
      echo "user name is: " & (await user_name())
    except:
      echo "can't get user name"
async_check main()

let greeting = Node("greeting")
greeting.generate_nimport
greeting.run