import asyncdispatch, ./support, ./re as rem

export asyncdispatch except async_check, with_timeout, add_timer

# Optional helpers for async, you don't have to use it

# spawn_async --------------------------------------------------------------------------------------
proc ignore_exceptions*[T](future: Future[T]): Future[T] {.async.} =
  try:    await future
  except: discard

proc ignore_exceptions*(future: Future[void]): Future[void] {.async.} =
  try:    await future
  except: discard

proc spawn_async*[T](future: Future[T], check = true) =
  if check: asyncdispatch.async_check future
  else:     asyncdispatch.async_check future.ignore_exceptions

proc spawn_async*[T](afn: proc: Future[T], check = true) =
  proc on_next_tick {.gcsafe.} =
    if check: asyncdispatch.async_check afn()
    else:
      try:
        asyncdispatch.async_check afn().ignore_exceptions
      except:
        discard
  asyncdispatch.call_soon on_next_tick


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