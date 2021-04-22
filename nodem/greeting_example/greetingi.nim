import nodem, asyncdispatch
export nodem, asyncdispatch

proc say_hi*(prefix: string): Future[string] {.async.} =
  return await nimport_async("greeting", say_hi)