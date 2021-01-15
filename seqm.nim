import system except find
import optionm, sugar, algorithm, supportm, sequtils
from random as random import nil

export sequtils


# is_empty -----------------------------------------------------------------------------------------
func is_empty*[T](list: openarray[T]): bool {.inline.} = list.len == 0


# first --------------------------------------------------------------------------------------------
func first*[T](list: openarray[T]): T {.inline.} =
  assert not list.is_empty, "can't get first from empty list"
  list[0]


# first_optional -----------------------------------------------------------------------------------
func first_optional*[T](list: openarray[T]): Option[T] =
  if list.is_empty: T.none else: list[0].some


# last ---------------------------------------------------------------------------------------------
func last*[T](list: openarray[T]): T {.inline.} =
  assert not list.is_empty, "can't get last from empty list"
  list[^1]


# findi --------------------------------------------------------------------------------------------
func findi*[T](list: openarray[T], value: T, start = 0): Option[int] =
  if start < (list.len - 1):
    for i in start..(list.len - 1):
      if list[i] == value: return i.some
  int.none

func findi*[T](list: openarray[T], check: (T) -> bool, start = 0): Option[int] =
  if start < (list.len - 1):
    for i in start..(list.len - 1):
      if check(list[i]): return i.some
  int.none


# find ---------------------------------------------------------------------------------------------
func find*[T](list: openarray[T], check: (T) -> bool, start = 0): Option[T] =
  if start < (list.len - 1):
    for i in start..(list.len - 1):
      let v = list[i]
      if check(v): return v.some
  T.none


# map ----------------------------------------------------------------------------------------------
func map*[V, R](list: openarray[V], op: (v: V, i: int) -> R): seq[R] {.inline.} =
  for i, v in list: result.add(op(v, i))


# sort_by ------------------------------------------------------------------------------------------
func sort_by*[T, C](list: openarray[T], op: (T) -> C): seq[T] {.inline.} = list.sortedByIt(op(it))


# sort ---------------------------------------------------------------------------------------------
func sort*[T](list: openarray[T]): seq[T] {.inline.} = list.sorted


# findi_min/max ------------------------------------------------------------------------------------
func findi_min*[T](list: openarray[T], op: (T) -> float): int =
  assert not list.is_empty
  list.map((v, i) => (op(v), i)).sort_by((pair) => pair[0])[0][1]

func findi_max*[T](list: openarray[T], op: (T) -> float): int =
  assert not list.is_empty
  list.map((v, i) => (op(v), i)).sort_by((pair) => pair[0])[^1][1]

test "findi_min/max":
  assert @[1.0, 2.0, 3.0].findi_min((v) => (v - 2.1).abs) == 1
  assert @[1.0, 2.0, 3.0].findi_max((v) => (v - 0.5).abs) == 2


# find_min, find_max -------------------------------------------------------------------------------
func find_min*[T](list: openarray[T], op: (T) -> float): T = list[list.findi_min(op)]
func find_max*[T](list: openarray[T], op: (T) -> float): T = list[list.findi_max(op)]


# filter -------------------------------------------------------------------------------------------
func filter*[V](list: openarray[Option[V]]): seq[V] =
  for o in list:
    if o.is_some: result.add o.get


# filter_map ---------------------------------------------------------------------------------------
func filter_map*[V, R](list: openarray[V], convert: proc (v: V): Option[R]): seq[R] =
  for v in list:
    let o = convert(v)
    if o.is_some: result.add o.get


# each ---------------------------------------------------------------------------------------------
func each*[T](list: openarray[T]; cb: proc (x: T): void): void {.inline.} =
  for v in list: cb(v)


# shuffle ------------------------------------------------------------------------------------------
func shuffle*[T](list: openarray[T], seed = 1): seq[T] =
  var rand = random.init_rand(seed)
  result = list.to_seq
  random.shuffle(rand, result)


# count --------------------------------------------------------------------------------------------
func count*[T](list: openarray[T], check: (T) -> bool): int {.inline.} =
  for v in list:
    if check(v): result.inc 1


# batches ------------------------------------------------------------------------------------------
func batches*[T](list: openarray[T], size: int): seq[seq[T]] =
  var i = 0
  while i < list.len:
    var batch: seq[T]
    for _ in 1..size:
      if i < list.len:
        batch.add list[i]
        i.inc 1
      else:
        break
    result.add batch

test "batches":
  assert @[1, 2, 3].batches(2) == @[@[1, 2], @[3]]
  assert @[1, 2].batches(2) == @[@[1, 2]]


# flatten ------------------------------------------------------------------------------------------
func flatten*[T](list: openarray[seq[T] | openarray[T]]): seq[T] =
  for list2 in list:
    for v in list2:
      result.add(v)


# init ---------------------------------------------------------------------------------------------
template init*[R, A](_: type[seq[R]], list: seq[A]): seq[R] =
  list.map(proc (v: A): R = R.init(v))
template init*[R, A, B](_: type[seq[R]], list: seq[(A, B)]): seq[R] =
  list.map(proc (v: (A, B)): R = R.init(v[0], v[1]))
template init*[R, A, B, C](_: type[seq[R]], list: seq[(A, B, C)]): seq[R] =
  list.map(proc (v: (A, B, C)): R = R.init(v[0], v[1], v[2]))


# to_seq ---------------------------------------------------------------------------------------------
# template to_seq*(list: seq[untyped], R): seq[typeof R] = R.init_seq(list)


# seq.== -------------------------------------------------------------------------------------------
# proc `==`*[A, B](a: openarray[A], b: openarray[B]): bool =
#   if a.len != b.len: return false
#   for i in 0..<a.len:
#     if a[i] != b[i]: return false
#   return true

# proc `==`(a: int, b: string): bool = $a == b
# proc `==`(a: string, b: int): bool = b == a

# proc `==`[A, B](a: openarray[A], b: openarray[B]): bool =
#   if a.len != b.len: return false
#   for i in 0..<a.len:
#     if a[i] != b[i]: return false
#   return true

# echo @[1] == @["1"]
