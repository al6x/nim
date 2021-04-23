# Have to be generated manually, because of the circular dependency
import nodem, asyncdispatch
export nodem, asyncdispatch

let user* = Address("user")

proc user_name*(): Future[string] {.async.} =
  return await nimport_async(user, user_name)