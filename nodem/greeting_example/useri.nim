# Auto-generated code, do not edit
import nodem, asyncdispatch
export nodem, asyncdispatch

proc user_name*(): Future[string] {.async.} =
  return await nimport_async("user", user_name)