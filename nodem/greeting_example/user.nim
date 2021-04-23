import ./greetingi

# Node works as server and client, asking for `say_hi` and exposing `user_name`

proc user_name*(): Future[string] {.async, nexport.} =
  return "Alex"

proc self: Future[void] {.async.} =
  echo await say_hi("Hi")
  # => Hi Alex


let address = Address("user")
address.generate_nimport
address.run self