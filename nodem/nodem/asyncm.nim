# Optional helpers for async, you don't have to use it with `nodem`
import ./supportm
import asyncdispatch

export asyncdispatch except async_check, with_timeout
export clean_async_error

# spawn --------------------------------------------------------------------------------------------
proc ignore_future[T](future: Future[T]): Future[void] {.async.} =
  try:    await future
  except: discard

proc spawn*[T](future: Future[T], check = true) =
  if check: asyncdispatch.async_check future
  else:     asyncdispatch.async_check ignore_future(future)

# timeout ------------------------------------------------------------------------------------------
proc timeout*[T](future: Future[T], timeout_ms: int, message = "timed out"): Future[T] {.async.} =
  if await asyncdispatch.with_timeout(future, timeout_ms):
    return await future
  else:
    throw message

proc timeout*(future: Future[void], timeout_ms: int, message = "timed out"): Future[void] {.async.} =
  if await asyncdispatch.with_timeout(future, timeout_ms):
    return
  else:
    raise new_exception(Exception, message)