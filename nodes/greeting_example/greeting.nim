import ./useri, asyncdispatch

var service_used = false
proc hi(name: string): string {.nexport.} =
  service_used = true
  "Hi " & name

proc self: Future[void] {.async.} =
  while not service_used:
    await sleep_async 1000
  echo "Feedback from user: " & feedback()

async_check self()
Address("greeting").run