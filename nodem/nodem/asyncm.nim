# Optional helpers for async, you don't have to use it with `nodem`
import asyncdispatch, re
import ./supportm

export asyncdispatch except async_check, with_timeout, add_timer


# spawn_async --------------------------------------------------------------------------------------
proc spawn_async*[T](future: Future[T], check = true) =
  asyncdispatch.async_check future


# timeout ------------------------------------------------------------------------------------------
proc with_timeout*[T](future: Future[T], timeout_ms: int, message = "timed out"): Future[T] {.async.} =
  if await asyncdispatch.with_timeout(future, timeout_ms):
    return await future
  else:
    throw message

proc with_timeout*(future: Future[void], timeout_ms: int, message = "timed out"): Future[void] {.async.} =
  if await asyncdispatch.with_timeout(future, timeout_ms):
    return
  else:
    raise new_exception(Exception, message)


# spawn_async --------------------------------------------------------------------------------------
proc clean_async_error*(error: string): string =
  error.replace(re"\nAsync traceback:[\s\S]+", "")


# add_timer ----------------------------------------------------------------------------------------
proc add_timer*(timeout_ms: int, cb: proc: void, once = true, immediatelly = false) =
  proc timer_wrapper(_: AsyncFD): bool {.gcsafe.} =
    cb()
    once
  if immediatelly: cb()
  asyncdispatch.add_timer(timeout_ms, once, timer_wrapper)
