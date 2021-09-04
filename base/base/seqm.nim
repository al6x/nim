import optionm, sugar, algorithm, supportm, tables
import sequtils except zip
from random as random import nil

export sequtils except zip


func contains*[T](list: openarray[T], check: (T) -> bool): bool =
  for v in list:
    if check(v): return true
  false


proc `&`*[T](x, y: openarray[T]): seq[T] =
  x.to_seq & y.to_seq


func is_empty*[T](list: openarray[T]): bool {.inline.} = list.len == 0
func is_blank*[T](list: openarray[T]): bool {.inline.} = list.len == 0


func fget*[T](list: openarray[T], check: (T) -> bool, start = 0): Option[T] =
  if start <= (list.len - 1):
    for i in start..(list.len - 1):
      let v = list[i]
      if check(v): return v.some
  T.none


func first*[T](list: openarray[T]): T {.inline.} =
  assert not list.is_empty, "can't get first from empty list"
  list[0]

func first*[T](list: openarray[T], check: (T) -> bool, start = 0): T =
  list.fget(check, start).get


func first_optional*[T](list: openarray[T]): Option[T] =
  if list.is_empty: T.none else: list[0].some


func last*[T](list: openarray[T]): T {.inline.} =
  assert not list.is_empty, "can't get last from empty list"
  list[^1]


proc take*[T](s: openarray[T], n: int): seq[T] =
  if n < s.len: s[0..(n - 1)] else: s.to_seq

test "take":
  assert @[1, 2, 3].take(2) == @[1, 2]
  assert @[1, 2, 3].take(10) == @[1, 2, 3]


proc delete*[T](s: var seq[T], cond: (T) -> bool): void =
  s = s.filter((v) => not cond(v))


func findi*[T](list: openarray[T], value: T, start = 0): Option[int] =
  if start <= (list.len - 1):
    for i in start..(list.len - 1):
      if list[i] == value: return i.some
  int.none

func findi*[T](list: openarray[T], check: (T) -> bool, start = 0): int =
  if start <= (list.len - 1):
    for i in start..(list.len - 1):
      if check(list[i]): return i
  -1

test "findi":
  assert @["a"].findi((v) => v == "a") == 0 # From error


template find_by*[T](list: seq[T], field: untyped, value: untyped): Option[T] =
  var result: Option[T]
  for v in `list`:
    if v.`field` == `value`: result = v.some
  result

test "find_by":
  let people = @[(name: "John"), (name: "Sarah")]
  assert people.find_by(name, "Sarah").get == (name: "Sarah")
  # expand_macros:
  #   echo people.find_by(name, "John")


template pick*[T](list: openarray[T], field: untyped): untyped =
  list.map((v) => v.`field`)
  # var result: seq[T.`field`] = @[]
  # for v in `list`:
  #   result.add v.`field`
  # result

test "pick":
  let people = @[(name: "John"), (name: "Sarah")]
  assert people.pick(name) == @["John", "Sarah"]

  proc name_fn(o: tuple[name: string]): string = o.name
  assert people.pick(name_fn) == @["John", "Sarah"]


func map*[V, R](list: openarray[V], op: (v: V, i: int) -> R): seq[R] {.inline.} =
  for i, v in list: result.add(op(v, i))


func sort_by*[T, C](list: openarray[T], op: (T) -> C): seq[T] {.inline.} = list.sortedByIt(op(it))

test "sort_by":
  assert @[(3, 2), (1, 3)].sort_by((v) => v) == @[(1, 3), (3, 2)]


func sort*[T](list: openarray[T]): seq[T] {.inline.} = list.sorted


func reverse*[T](list: openarray[T]): seq[T] {.inline.} = list.reversed


func findi_min*[T](list: openarray[T], op: (T) -> float): Option[int] =
  if list.is_empty: return
  var (min, min_i) = (op(list[0]), 0)
  for i in 1..(list.len - 1):
    let m = op(list[i])
    if m < min:
      min = m
      min_i = i
  min_i.some

func findi_min*(list: openarray[float]): Option[int] =
  list.findi_min((v) => v)


func findi_max*[T](list: openarray[T], op: (T) -> float): Option[int] =
  if list.is_empty: return
  var (max, max_i) = (op(list[0]), 0)
  for i in 1..(list.len - 1):
    let m = op(list[i])
    if m > max:
      max = m
      max_i = i
  max_i.some

func findi_max*(list: openarray[float]): Option[int] =
  list.findi_max((v) => v)

test "findi_min/max":
  assert @[1.0, 2.0, 3.0].findi_min((v) => (v - 2.1).abs).get == 1
  assert @[1.0, 2.0, 3.0].findi_max((v) => (v - 0.5).abs).get == 2


func find_min*[T](list: openarray[T], op: (T) -> float): Option[T] =
  let i = list.findi_min(op)
  if i.is_none: return
  list[i.get].some

func find_max*[T](list: openarray[T], op: (T) -> float): Option[T] =
  let i = list.findi_max(op)
  if i.is_none: return
  list[i.get].some


func reject*[V](list: openarray[V], op: (V) -> bool): seq[V] =
  list.filter((v) => not op(v))


func filter*[V](list: openarray[Option[V]]): seq[V] =
  for o in list:
    if o.is_some: result.add o.get


func filter_map*[V, R](list: openarray[V], convert: (V) -> Option[R]): seq[R] =
  for v in list:
    let o = convert(v)
    if o.is_some: result.add o.get


func filter_map*[V, R](list: openarray[V], convert: (V, int) -> Option[R]): seq[R] =
  for i, v in list:
    let o = convert(v, i)
    if o.is_some: result.add o.get


func each*[T](list: openarray[T]; cb: (T) -> void): void {.inline.} =
  for v in list: cb(v)


func shuffle*[T](list: openarray[T], seed = 1): seq[T] =
  var rand = random.init_rand(seed)
  result = list.to_seq
  random.shuffle(rand, result)

func shuffle*[T](list: openarray[T], rand: random.Rand): seq[T] =
  result = list.to_seq
  random.shuffle(rand, result)


func count*[T](list: openarray[T], check: (T) -> bool): int {.inline.} =
  for v in list:
    if check(v): result.inc 1


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


func flatten*[T](list: openarray[seq[T] | openarray[T]]): seq[T] =
  for list2 in list:
    for v in list2:
      result.add(v)


func unique*[T](list: openarray[T]): seq[T] =
  list.deduplicate


func zip*[A, B](a: openarray[A], b: openarray[B]): seq[(A, B)] =
  # Difference from sequtils.zip is that it requires a and b sizes to be the same
  assert a.len == b.len
  sequtils.zip(a, b)

func zip*[A, B, R](a: openarray[A], b: openarray[B], op: (A, B) -> R): seq[R] =
  sequtils.zip(a, b).map((pair) => op(pair[0], pair[1]))


proc add_capped*[T](list: var seq[T], v: T, cap: int): void =
  assert cap > 0
  if list.len < cap: list.add v
  else:              list = list[1..(cap - 1)] & @[v]

test "add_capped":
  var l: seq[int]
  l.add_capped(1, 2)
  l.add_capped(2, 2)
  l.add_capped(3, 2)
  assert l == @[2, 3]


proc prepend_capped*[T](list: var seq[T], v: T, cap: int): void =
  assert cap > 0
  list = @[v] & (if list.len < cap: list else: list[0..(cap - 2)])

test "prepend_capped":
  var l: seq[int]
  l.prepend_capped(1, 2)
  l.prepend_capped(2, 2)
  l.prepend_capped(3, 2)
  assert l == @[3, 2]


proc init*[R, A](_: type[seq[R]], list: seq[A]): seq[R] =
  list.map(proc (v: A): R = R.init(v))
proc init*[R, A, B](_: type[seq[R]], list: seq[(A, B)]): seq[R] =
  list.map(proc (v: (A, B)): R = R.init(v[0], v[1]))
proc init*[R, A, B, C](_: type[seq[R]], list: seq[(A, B, C)]): seq[R] =
  list.map(proc (v: (A, B, C)): R = R.init(v[0], v[1], v[2]))


proc group_by*[V, K](list: seq[V] | ref seq[V], op: (V) -> K): Table[K, seq[V]] =
  for v in list: result.mget_or_put(op(v), @[]).add v

test "group_by":
  assert @["aa", "ab", "bc"].group_by((s) => s[0]) == {'a': @["aa", "ab"], 'b': @["bc"]}.to_table


proc count_by*[V, K](list: seq[V] | ref seq[V], op: (v: V) -> K): Table[K, int] =
  for v in list:
    let k = op(v)
    result[k] = result.get_or_default(k, 0) + 1

test "count_by":
  assert @["aa", "ab", "bc"].count_by((s) => s[0]) == {'a': 2, 'b': 1}.to_table