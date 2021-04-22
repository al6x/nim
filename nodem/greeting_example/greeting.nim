import ./useri, nodem/supportm

proc say_hi*(prefix: string): Future[string] {.async, nexport.} =
  let name = await user_name() # Nested, circular call
  return prefix & " " & name

proc self: Future[void] {.async.} =
  while true:
    await sleep_async 1000
    try:
      echo "user name is: " & (await user_name())
    except:
      echo "can't get user name"

Address("greeting").run self