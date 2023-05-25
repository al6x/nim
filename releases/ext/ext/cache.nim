import base

# cache --------------------------------------------------------------------------------------------
proc cache*[R](fn: () -> R): (() -> R) =
  var cached: ref R
  return proc (): R =
    if cached.is_nil: cached = fn().to_ref
    cached[]

test "cache":
  proc calculate_slow(): float = 2.0
  let calculate = calculate_slow.cache
  assert calculate() =~ 2.0


# cache, 1 argument --------------------------------------------------------------------------------
type Cache1*[A, R] = Table[A, (R, Time)]
proc init*[A, R](_: type[Cache1[A, R]]): Cache1[A, R] = Cache1[A, R]()

proc build_cache*[A, R](fn: (A) -> R): Cache1[A, R] = result

proc get*[A, R](cache: var Cache1[A, R], fn: (A) -> R, a: A): R =
  if a notin cache: cache[a] = (fn(a), Time.now)
  cache[a][0]

proc get*[A, R](cache: var Cache1[A, R], fn: (A) -> R, a: A, is_expired: (R, Time) -> bool): R =
  if a notin cache: cache[a] = (fn(a), Time.now)
  var (value, timestamp) = cache[a]
  if is_expired(value, timestamp):
    value = fn(a)
    cache[a] = (value, Time.now)
  value

proc cache*[A, R](fn: (A) -> R): ((A) -> R) =
  var cache_storage: Cache1[A, R] = fn.build_cache
  return proc (a: A): R = cache_storage.get(fn, a)

test "cache, 1":
  proc x2_slow(a: float): float = 2.0 * a
  let x2 = x2_slow.cache
  assert x2(2.0) =~ 4.0


# cache, 2 arguments ------------------------------------------------------------------------------
type KeyOf2[A, B] = (A, B)
proc hash(v: KeyOf2): Hash = v.autohash

type Cache2*[A, B, R] = Table[KeyOf2[A, B], (R, Time)]
proc init*[A, B, R](_: type[Cache2[A, B, R]]): Cache2[A, B, R] = Cache2[A, B, R]()

proc build_cache*[A, B, R](fn: (A, B) -> R): Cache2[A, B, R] = result

proc get*[A, B, R](cache: var Cache2[A, B, R], fn: (A, B) -> R, a: A, b: B): R =
  let key: KeyOf2[A, B] = (a, b)
  if key notin cache: cache[key] = (fn(a, b), Time.now)
  cache[key][0]

proc get*[A, B, R](cache: var Cache2[A, B, R], fn: (A, B) -> R, a: A, b: B, is_expired: (R, Time) -> bool): R =
  let key: KeyOf2[A, B] = (a, b)
  if key notin cache: cache[key] = (fn(a, b), Time.now)
  var (value, timestamp) = cache[key]
  if is_expired(value, timestamp):
    value = fn(a, b)
    cache[key] = (value, Time.now)
  value

proc cache*[A, B, R](fn: (A, B) -> R): ((A, B) -> R) =
  var cache_storage: Cache2[A, B, R] = fn.build_cache
  return proc (a: A, b: B): R = cache_storage.get(fn, a, b)

test "cached, 2":
  proc add_slow(a, b: float): float = a + b
  var add_cache = add_slow.build_cache
  let add = add_slow.cache
  assert add(2.0, 2.0) =~ 4.0

  var cache = add_slow.build_cache
  assert cache.get(add_slow, 2.0, 2.0) =~ 4.0
  assert cache.get(add_slow, 2.0, 2.0, (_, timestamp) => false) =~ 4.0


# cache, 3 arguments -------------------------------------------------------------------------------
type KeyOf3[A, B, C] = (A, B, C)
proc hash(v: KeyOf3): Hash = v.autohash

type Cache3*[A, B, C, R] = Table[KeyOf3[A, B, C], (R, Time)]
proc init*[A, B, C, R](_: type[Cache3[A, B, C, R]]): Cache3[A, B, C, R] = Cache3[A, B, C, R]()

proc build_cache*[A, B, C, R](fn: (A, B, C) -> R): Cache3[A, B, C, R] = result

proc get*[A, B, C, R](
  cache_storage: var Cache3[A, B, C, R], fn: (A, B, C) -> R, a: A, b: B, c: C
): R =
  let key: KeyOf3[A, B, C] = (a, b, c)
  if key notin cache_storage: cache_storage[key] = (fn(a, b, c), Time.now)
  cache_storage[key][0]

proc get*[A, B, C, R](
  cache: var Cache3[A, B, C, R], fn: (A, B, C) -> R, a: A, b: B, c: C, is_expired: (R, Time) -> bool
): R =
  let key: KeyOf3[A, B, C] = (a, b, c)
  if key notin cache: cache[key] = (fn(a, b, c), Time.now)
  var (value, timestamp) = cache[key]
  if is_expired(value, timestamp):
    value = fn(a, b, c)
    cache[key] = (value, Time.now)
  value

proc cache*[A, B, C, R](fn: (A, B, C) -> R): ((A, B, C) -> R) =
  var cache_storage: Cache3[A, B, C, R] = fn.build_cache
  return proc (a: A, b: B, c: C): R = cache_storage.get(fn, a, b, c)

test "cache, 3":
  proc add_slow(a, b, c: float): float = a + b + c
  let add = add_slow.cache
  assert add(2.0, 2.0, 2.0) =~ 6.0


# cache, 4 arguments -------------------------------------------------------------------------------
type KeyOf4[A, B, C, D] = (A, B, C, D)
proc hash(v: KeyOf4): Hash = v.autohash

type Cache4*[A, B, C, D, R] = Table[KeyOf4[A, B, C, D], (R, Time)]
proc init*[A, B, C, D, R](_: type[Cache4[A, B, C, D, R]]): Cache4[A, B, C, D, R] = Cache4[A, B, C, D, R]()

proc build_cache*[A, B, C, D, R](fn: (A, B, C, D) -> R): Cache4[A, B, C, D, R] = result

proc get*[A, B, C, D, R](
  cache: var Cache4[A, B, C, D, R], fn: (A, B, C, D) -> R, a: A, b: B, c: C, d: D
): R =
  let key: KeyOf4[A, B, C, D] = (a, b, c, d)
  if key notin cache: cache[key] = (fn(a, b, c, d), Time.now)
  cache[key][0]

proc get*[A, B, C, D, R](
  cache: var Cache4[A, B, C, D, R], fn: (A, B, C, D) -> R, a: A, b: B, c: C, d: D, is_expired: (R) -> bool
): R =
  let key: KeyOf4[A, B, C, D] = (a, b, c, d)
  if key notin cache: cache[key] = (fn(a, b, c, d), Time.now)
  var (value, timestamp) = cache[key]
  if is_expired(value, timestamp):
    value = fn(a, b, c, d)
    cache[key] = (value, Time.now)
  value

proc cache*[A, B, C, D, R](fn: (A, B, C, D) -> R): ((A, B, C, D) -> R) =
  var cache_storage: Cache4[A, B, C, D, R] = fn.build_cache
  return proc (a: A, b: B, c: C, d: D): R = cache_storage.get(fn, a, b, c, d)

test "cache, 4":
  proc add_slow(a, b, c, d: float): float = a + b + c + d
  let add = add_slow.cache
  assert add(2.0, 2.0, 2.0, 2.0) =~ 8.0