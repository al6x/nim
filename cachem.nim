import supportm, tablem, hashm

# cache --------------------------------------------------------------------------------------------
proc cache*[R](fn: proc (): R): (proc(): R) =
  var cached: ref R
  return proc (): R =
    if cached.is_nil: cached = fn().to_ref
    cached[]

test "cache":
  proc calculate_slow(): float = 2.0
  let calculate = calculate_slow.cache
  assert calculate() == 2.0


# cache, 1 argument --------------------------------------------------------------------------------
type Cache1*[A, R] = Table[A, ref R]
proc init*[A, R](_: type[Cache1[A, R]]): Cache1[A, R] = Cache1[A, R]()

proc build_cache*[A, R](fn: proc (a: A): R): Cache1[A, R] = result

proc get*[A, R](cache: var Cache1[A, R], fn: proc (a: A): R, a: A): R =
  if a notin cache: cache[a] = fn(a).to_ref
  cache[a][]

proc cache*[A, R](fn: proc (a: A): R): (proc (a: A): R) =
  var cache_storage: Cache1[A, R] = fn.build_cache
  return proc (a: A): R = cache_storage.get(fn, a)

test "cache, 1":
  proc x2_slow(a: float): float = 2.0 * a
  let x2 = x2_slow.cache
  assert x2(2.0) == 4.0


# cache, 2 arguments ------------------------------------------------------------------------------
type KeyOf2[A, B] = (A, B)
proc hash(v: KeyOf2): Hash = v.autohash

type Cache2*[A, B, R] = Table[KeyOf2[A, B], ref R]
proc init*[A, B, R](_: type[Cache2[A, B, R]]): Cache2[A, B, R] = Cache2[A, B, R]()

proc build_cache*[A, B, R](fn: proc (a: A, b: B): R): Cache2[A, B, R] = result

proc get*[A, B, R](cache: var Cache2[A, B, R], fn: proc (a: A, b: B): R, a: A, b: B): R =
  let key: KeyOf2[A, B] = (a, b)
  if key notin cache: cache[key] = fn(a, b).to_ref
  cache[key][]

proc cache*[A, B, R](fn: proc (a: A, b: B): R): (proc (a: A, b: B): R) =
  var cache_storage: Cache2[A, B, R] = fn.build_cache
  return proc (a: A, b: B): R = cache_storage.get(fn, a, b)

test "cached, 2":
  proc add_slow(a, b: float): float = a + b
  var add_cache = add_slow.build_cache
  let add = add_slow.cache
  assert add(2.0, 2.0) == 4.0


# cache, 3 arguments -------------------------------------------------------------------------------
type KeyOf3[A, B, C] = (A, B, C)
proc hash(v: KeyOf3): Hash = v.autohash

type Cache3*[A, B, C, R] = Table[KeyOf3[A, B, C], ref R]
proc init*[A, B, C, R](_: type[Cache3[A, B, C, R]]): Cache3[A, B, C, R] = Cache3[A, B, C, R]()

proc build_cache*[A, B, C, R](fn: proc (a: A, b: B, c: C): R): Cache3[A, B, C, R] = result

proc get*[A, B, C, R](
  cache_storage: var Cache3[A, B, C, R], fn: proc (a: A, b: B, c: C): R, a: A, b: B, c: C
): R =
  let key: KeyOf3[A, B, C] = (a, b, c)
  if key notin cache_storage: cache_storage[key] = fn(a, b, c).to_ref
  cache_storage[key][]

proc cache*[A, B, C, R](fn: proc (a: A, b: B, c: C): R): (proc (a: A, b: B, c: C): R) =
  var cache_storage: Cache3[A, B, C, R] = fn.build_cache
  return proc (a: A, b: B, c: C): R = cache_storage.get(fn, a, b, c)

test "cache, 3":
  proc add_slow(a, b, c: float): float = a + b + c
  let add = add_slow.cache
  assert add(2.0, 2.0, 2.0) == 6.0


# cache, 4 arguments -------------------------------------------------------------------------------
type KeyOf4[A, B, C, D] = (A, B, C, D)
proc hash(v: KeyOf4): Hash = v.autohash

type Cache4*[A, B, C, D, R] = Table[KeyOf4[A, B, C, D], ref R]
proc init*[A, B, C, D, R](_: type[Cache4[A, B, C, D, R]]): Cache4[A, B, C, D, R] = Cache4[A, B, C, D, R]()

proc build_cache*[A, B, C, D, R](fn: proc (a: A, b: B, c: C, d: D): R): Cache4[A, B, C, D, R] = result

proc get*[A, B, C, D, R](
  cache: var Cache4[A, B, C, D, R], fn: proc (a: A, b: B, c: C, d: D): R, a: A, b: B, c: C, d: D
): R =
  let key: KeyOf4[A, B, C, D] = (a, b, c, d)
  if key notin cache: cache[key] = fn(a, b, c, d).to_ref
  cache[key][]

proc cache*[A, B, C, D, R](fn: proc (a: A, b: B, c: C, d: D): R): (proc (a: A, b: B, c: C, d: D): R) =
  var cache_storage: Cache4[A, B, C, D, R] = fn.build_cache
  return proc (a: A, b: B, c: C, d: D): R = cache_storage.get(fn, a, b, c, d)

test "cache, 4":
  proc add_slow(a, b, c, d: float): float = a + b + c + d
  let add = add_slow.cache
  assert add(2.0, 2.0, 2.0, 2.0) == 8.0