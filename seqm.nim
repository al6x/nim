import system except find
import optionm, sugar, algorithm, supportm, sequtils
from random as random import nil

export sequtils


# is_empty -----------------------------------------------------------------------------------------
proc is_empty*[T](list: openarray[T]): bool {.inline.} = list.len == 0


# first --------------------------------------------------------------------------------------------
proc first*[T](list: openarray[T]): T {.inline.} =
  assert list.len > 0, "can't get first from empty list"
  list[0]


# last ---------------------------------------------------------------------------------------------
proc last*[T](list: openarray[T]): T {.inline.} =
  assert list.len > 0, "can't get last from empty list"
  list[^1]


# find ---------------------------------------------------------------------------------------------
func find*[T](list: openarray[T], check: (T) -> bool): Option[T] {.inline.} =
  for v in list:
    if check(v): return v.some
  T.none


# map ----------------------------------------------------------------------------------------------
proc map*[V, R](list: openarray[V], op: (v: V, i: int) -> R): seq[R] {.inline.} =
  for i, v in list: result.add(op(v, i))


# sort_by ------------------------------------------------------------------------------------------
proc sort_by*[T, C](list: openarray[T], op: (T) -> C): seq[T] {.inline.} = list.sortedByIt(op(it))


# sort ---------------------------------------------------------------------------------------------
proc sort*[T](list: openarray[T]): seq[T] {.inline.} = list.sorted


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


# filter_map ---------------------------------------------------------------------------------------
proc filter_map*[V, R](list: openarray[V], convert: proc (v: V): Option[R]): seq[R] =
  for v in list:
    let o = convert(v)
    if o.is_some: result.add o.get


# each ---------------------------------------------------------------------------------------------
proc each*[T](list: openarray[T]; cb: proc (x: T): void): void {.inline.} =
  for v in list: cb(v)


# shuffle ------------------------------------------------------------------------------------------
proc shuffle*[T](list: openarray[T], seed = 1): seq[T] =
  var rand = random.init_rand(seed)
  result = list.to_seq
  random.shuffle(rand, result)


# count --------------------------------------------------------------------------------------------
func count*[T](list: openarray[T], check: (T) -> bool): int {.inline.} =
  for v in list:
    if check(v): result.inc 1


# batches ------------------------------------------------------------------------------------------
proc batches*[T](list: openarray[T], size: int): seq[seq[T]] =
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
proc flatten*[T](list: openarray[seq[T] | openarray[T]]): seq[T] =
  for list2 in list:
    for v in list2:
      result.add(v)


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
