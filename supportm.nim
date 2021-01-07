import strformat, macros, sugar, options, strutils, os, unicode, tables
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


# test ---------------------------------------------------------------------------------------------
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


# init ---------------------------------------------------------------------------------------------
proc init*[T](_: type[string], v: T): string = $v


# to -----------------------------------------------------------------------------------------------
template to*[F,T](f: F, _: type[T]): T = T.init(f)


# int.align ----------------------------------------------------------------------------------------
proc align*(n: int, digits: int): string = ($n).align(digits, '0')


# T.$ ----------------------------------------------------------------------------------------------
proc `$`*[T: typed](x: ref T): string = "->" & $(x[])


# p --------------------------------------------------------------------------------------
const p* = echo


# string.error_type --------------------------------------------------------------------------------
# Extract error type from string message, the last part of `some text :some_type`
func error_type*(message: string): string =
  let error_type_re = nre.re("(?i).*\\s:([a-z0-9_-]+)$")
  if nre.match(message, error_type_re).is_some: nre.split(message, nre.re("\\s:"))[^1]
  else:                                         ""

test "error_type":
  assert "No security definition has been found :not_found".error_type == "not_found"


# timer_sec ----------------------------------------------------------------------------------------
proc timer_sec*(): (() -> int) =
  let started_at = nt.utc(nt.now())
  () => nt.in_seconds(nt.`-`(nt.utc(nt.now()), started_at)).int