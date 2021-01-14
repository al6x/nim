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
proc cache*[A, R](fn: proc (a: A): R): (proc (a: A): R) =
  var cached = init_table[A, ref R]()
  return proc (a: A): R =
    if a notin cached: cached[a] = fn(a).to_ref
    cached[a][]

test "cache, 1":
  proc x2_slow(a: float): float = 2.0 * a
  let x2 = x2_slow.cache
  assert x2(2.0) == 4.0


# cache, 2 arguments -------------------------------------------------------------------------------
type KeyOf2[A, B] = (A, B)
proc hash(v: KeyOf2): Hash = v.autohash

proc cache*[A, B, R](fn: proc (a: A, b: B): R): (proc (a: A, b: B): R) =
  var cached = init_table[KeyOf2[A, B], ref R]()
  return proc (a: A, b: B): R =
    let key: KeyOf2[A, B] = (a, b)
    if key notin cached: cached[key] = fn(a, b).to_ref
    cached[key][]

test "cache, 2":
  proc add_slow(a, b: float): float = a + b
  let add = add_slow.cache
  assert add(2.0, 2.0) == 4.0


# cache, 3 arguments -------------------------------------------------------------------------------
type KeyOf3[A, B, C] = (A, B, C)
proc hash(v: KeyOf3): Hash = v.autohash

proc cache*[A, B, C, R](fn: proc (a: A, b: B, c: C): R): (proc (a: A, b: B, c: C): R) =
  var cached = init_table[KeyOf3[A, B, C], ref R]()
  return proc (a: A, b: B, c: C): R =
    let key: KeyOf3[A, B, C] = (a, b, c)
    if key notin cached: cached[key] = fn(a, b, c).to_ref
    cached[key][]

test "cache, 3":
  proc add_slow(a, b, c: float): float = a + b + c
  let add = add_slow.cache
  assert add(2.0, 2.0, 2.0) == 6.0


# cache, 4 arguments -------------------------------------------------------------------------------
type KeyOf4[A, B, C, D] = (A, B, C, D)
proc hash(v: KeyOf4): Hash = v.autohash

proc cache*[A, B, C, D, R](fn: proc (a: A, b: B, c: C, d: D): R): (proc (a: A, b: B, c: C, d: D): R) =
  var cached = init_table[KeyOf4[A, B, C, D], ref R]()
  return proc (a: A, b: B, c: C, d: D): R =
    let key: KeyOf4[A, B, C, D] = (a, b, c, d)
    if key notin cached: cached[key] = fn(a, b, c, d).to_ref
    cached[key][]

test "cache, 4":
  proc add_slow(a, b, c, d: float): float = a + b + c + d
  let add = add_slow.cache
  assert add(2.0, 2.0, 2.0, 2.0) == 8.0