# Optional helpers for async, you don't have to use it with `nodem`
import ./supportm
import asyncdispatch except async_check, with_timeout

export asyncdispatch except async_check, with_timeout
export clean_async_error

# spawn --------------------------------------------------------------------------------------------
proc ignore_future[T](future: Future[T]): Future[void] {.async.} =
  try:    await future
  except: discard

proc spawn*[T](future: Future[T], check = true) =
  if check: asyncdispatch.async_check future
  else:     asyncdispatch.async_check ignore_future(future)

# with_timeout -------------------------------------------------------------------------------------
proc with_timeout*[T](future: Future[T], error = "timed out"): Future[void] {.async.} =
  if await asyncdispatch.with_timeout(future): return await future
  else:                                        throw error