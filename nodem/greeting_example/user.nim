import ./greetingi

proc user_name*(): Future[string] {.async, nexport.} =
  return "Alex"

proc self: Future[void] {.async.} =
  echo await say_hi("Hi")
  # => Hi Alex

Address("user").run self