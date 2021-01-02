import system except find
import strformat, macros, sequtils, sugar, options, strutils, tables, os, hashes, json, algorithm, math,
  unicode
from random as random import nil
from std/times as nt import nil
from std/nre as nre import nil


# test ---------------------------------------------------------------------------------------------
let test_enabled = get_env("test", "false").to_lower
template test*(name: string, body) =
  var lname = name.to_lower
  if test_enabled == "true" or test_enabled == lname:
    try:
      body
    except:
      echo "test '", lname, "' failed"
      raise get_current_exception()


# slow_test ----------------------------------------------------------------------------------------
var test_group_cache = init_table[string, string]()
template test*(name: string, group: string, body) =
  var lname  = name.to_lower
  var lgroup = group.to_lower
  if lgroup notin test_group_cache:
    test_group_cache[group] = get_env("test_" & lgroup, "true").to_lower

  if (test_enabled == "true" and test_group_cache[lgroup] == "true") or test_enabled == lname:
    try:
      body
    except:
      echo "test '", lname, "' '", lgroup, "' failed"
      raise get_current_exception()


# aqual --------------------------------------------------------------------------------------------
proc aqual*(a: float, b: float, epsilon: float): bool =
  (a - b).abs() <= epsilon


# throw ----------------------------------------------------------------------------------
template throw*(message: string) = raise newException(CatchableError, message)


# to_ref ---------------------------------------------------------------------------------
proc to_ref*[T](o: T): ref T =
  result.new
  result[] = o


# throw ----------------------------------------------------------------------------------
proc each*[T](list: openarray[T]; cb: proc (x: T): void): void =
  for v in list: cb(v)


# Table.map ------------------------------------------------------------------------------
proc map*[K, V, R](table: Table[K, V], convert: proc (v: V, k: K): R): Table[K, R] =
  for k, v in table: result[k] = convert(v, k)

proc map*[K, V, R](table: Table[K, V], convert: proc (v: V): R): Table[K, R] =
  for k, v in table: result[k] = convert(v)


# Table.filter ---------------------------------------------------------------------------
proc filter*[K, V](table: Table[K, V], predicate: proc (v: V): bool): Table[K, V] =
  for k, v in table:
    if predicate(v): result[k] = v

proc filter*[K, V](table: Table[K, V], predicate: proc (v: V, k: K): bool): Table[K, V] =
  for k, v in table:
    if predicate(v, k): result[k] = v


# Table.filter_map -----------------------------------------------------------------------
proc filter_map*[K, V, R](table: Table[K, V], convert: proc (v: V): Option[R]): Table[K, R] =
  for k, v in table:
    let o = convert(v)
    if o.is_some: result[k] = o.get


# Table.keys -----------------------------------------------------------------------------
proc keys*[K, V](table: Table[K, V]): seq[K] =
  for k in table.keys: result.add k


# openarray.filter_map -----------------------------------------------------------------------
proc filter_map*[V, R](list: openarray[V], convert: proc (v: V): Option[R]): seq[R] =
  for v in list:
    let o = convert(v)
    if o.is_some: result.add o.get


# openarray.first -----------------------------------------------------------------------
proc first*[T](list: openarray[T]): T =
  assert list.len > 0, "can't get first from empty list"
  list[0]


# openarray.shuffle --------------------------------------------------------------------------------
proc shuffle*[T](list: openarray[T], seed = 1): seq[T] =
  var rand = random.init_rand(seed)
  result = list.to_seq
  random.shuffle(rand, result)


# openarray.is_empty -------------------------------------------------------------------------------
proc is_empty*[T](list: openarray[T]): bool = list.len == 0


# string.is_empty -------------------------------------------------------------------------------
proc is_empty*(s: string): bool = s == ""


# string.take --------------------------------------------------------------------------------------
proc take*(s: string, n: int): string =
  if n < s.len: s[0..(n - 1)] else: s

test "take":
  assert "abcd".take(2) == "ab"
  assert "ab".take(10) == "ab"

# string.split2,3,4 -------------------------------------------------------------------------------
proc split2*(s: string, by: string): (string, string) =
  let list = s.split(by)
  assert list.len == 2, fmt"expected 2 but found {list.len} elements after splitting {s} by {by}"
  (list[0], list[1])

proc split3*(s: string, by: string): (string, string, string) =
  let list = s.split(by)
  assert list.len == 3, fmt"expected 3 but found {list.len} elements after splitting {s} by {by}"
  (list[0], list[1], list[2])

proc split4*(s: string, by: string): (string, string, string, string) =
  let list = s.split(by)
  assert list.len == 4, fmt"expected 4 but found {list.len} elements after splitting {s} by {by}"
  (list[0], list[1], list[2], list[3])


# to_s ---------------------------------------------------------------------------------------------
proc to_s*[T](v: T): string = $v


# openarray.last -----------------------------------------------------------------------------------
proc last*[T](list: openarray[T]): T =
  assert list.len > 0, "can't get last from empty list"
  list[list.len - 1]


# openarray.find -----------------------------------------------------------------------------------
func find*[T](list: openarray[T], check: (T) -> bool): Option[T] =
  for v in list:
    if check(v): return v.some
  T.none


# Option.get -----------------------------------------------------------------------------------
proc get*[T](o: Option[T], otherwise: (proc (): T)): T =
  if o.is_some: o.get else: otherwise()


# Option.get -----------------------------------------------------------------------------------
proc ensure*[T](o: Option[T], message: string): T =
  assert o.is_some, message
  o.get


# openarray.find -----------------------------------------------------------------------------------
proc sort_by*[T, C](list: openarray[T], op: (T) -> C): seq[T] = list.sortedByIt(op(it))


# openarray.count ----------------------------------------------------------------------------------
func count*[T](list: openarray[T], check: (T) -> bool): int =
  for v in list:
    if check(v): result.inc 1


# openarray.count ----------------------------------------------------------------------------------
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


# openarray.count ----------------------------------------------------------------------------------
proc flatten*[T](list: openarray[seq[T] | openarray[T]]): seq[T] =
  for list2 in list:
    for v in list2:
      result.add(v)


# openarray.to_table -------------------------------------------------------------------------------
proc to_table*[V, K](list: openarray[V], key: (V) -> K): Table[K, V] =
  for v in list: result[key(v)] = v

proc to_table*[V, K](list: openarray[V], key: (V, int) -> K): Table[K, V] =
  for i, v in list: result[key(v, i)] = v


# int.align ----------------------------------------------------------------------------------------
proc align*(n: int, digits: int): string = ($n).align(digits, '0')


# T.hash -------------------------------------------------------------------------------------------
proc autohash*[T: tuple|object](o: T): Hash =
  var h: Hash = 0
  for f in o.fields: h = h !& f.hash
  !$h


# T.$ ----------------------------------------------------------------------------------------------
proc `$`[T: typed](x: ref T): string = "->" & $(x[])


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


# p --------------------------------------------------------------------------------------
const p* = echo


# Constants ------------------------------------------------------------------------------
let sec_ms* = 1000; let min_ms* = 60 * sec_ms; let hour_ms* = 60 * min_ms;
let day_ms* = 24 * hour_ms

let min_sec* = 60; let hour_sec* = 60 * min_sec; let day_sec* = 24 * hour_sec


# Docs -----------------------------------------------------------------------------------
type
  DocKind* = enum Text, Todo

  DocItem* = object
    case kind: DocKind

    of Text:
      title: string
      text:  string

    of Todo:
      todo:     string
      priority: string

    tags: seq[string]

var docs*: seq[DocItem]
let todo_priorities = ["high", "normal", "low"]

proc doc*(title: string, text: string, tags: seq[string] = @[]): void =
  docs.add DocItem(kind: Text, title: title, text: text, tags: tags)

proc todo*(todo: string, priority: string = "low", tags: seq[string] = @[]): void =
  assert priority in todo_priorities, fmt"wrong priority {priority}"
  docs.add DocItem(kind: Todo, priority: priority, tags: tags)


# Errorneous -----------------------------------------------------------------------------
type Errorneous*[T] = object
  case is_error*: bool
  of true:
    error*: string
  of false:
    value*: T

func get*[T](e: Errorneous[T]): T =
  if e.is_error: throw(e.error) else: e.value

func failure*(T: type, error: string): Errorneous[T] = Errorneous[T](is_error: true, error: error)
func success*[T](value: T): Errorneous[T] = Errorneous[T](is_error: false, value: value)

# string.error_type --------------------------------------------------------------------------------
# Extract error type from string message, the last part of `some text :some_type`
func error_type*(message: string): string =
  let error_type_re = nre.re("(?i).*\\s:([a-z0-9_-]+)$")
  if nre.match(message, error_type_re).is_some: nre.split(message, nre.re("\\s:")).last
  else:                            ""

test "error_type":
  assert "No security definition has been found :not_found".error_type == "not_found"


# T.to_json ----------------------------------------------------------------------------------------
proc to_json*[T](v: T, pretty = true): string =
  if pretty: (%v).pretty else: $(%v)


# T.from_json ----------------------------------------------------------------------------------------
proc from_json*[T](v: type[T], json: string): T = json.parse_json.to(T)


# timer_sec ----------------------------------------------------------------------------------------
proc timer_sec*(): (() -> int) =
  let started_at = nt.utc(nt.now())
  () => nt.in_seconds(nt.`-`(nt.utc(nt.now()), started_at)).int