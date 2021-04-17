import strformat, macros, sugar, strutils, unicode, tables, envm
from std/times as nt import nil
from std/nre as nre import nil
from std/options as stdoptions import nil
from terminalm as terminal import nil


# test ---------------------------------------------------------------------------------------------
let test_enabled_s = if "test" in env: env["test"] else: "false"
let test_enabled   = test_enabled_s == "true"
template test*(name: string, body) =
  # block:
  if test_enabled or test_enabled_s == name.to_lower:
    try:
      body
    except Exception as e:
      echo "test '", name.to_lower, "' failed"
      raise e


# test ---------------------------------------------------------------------------------------------
var test_group_cache = init_table[string, string]()
template test*(name: string, group, body) =
  block:
    var lname  = name.to_lower
    var lgroup = group.to_lower
    if lgroup notin test_group_cache:
      let tlgroup = "test_" & lgroup
      test_group_cache[group] = (if tlgroup in env: env[tlgroup] else: "true").to_lower

    if (test_enabled and test_group_cache[lgroup] == "true") or test_enabled_s == lname:
      try:
        body
      except Exception as e:
        echo "test '", lname, "' '", lgroup, "' failed"
        raise e


# aqual --------------------------------------------------------------------------------------------
# proc aqual*(a: float, b: float, epsilon: float): bool =
#   (a - b).abs() <= epsilon


# throw --------------------------------------------------------------------------------------------
template throw*(message: string) = raise newException(Exception, message)
template throw*(exception: Exception | ref Exception) = raise exception

# A simple way to message user by throwing an error
# type MessageError* = object of Exception
template throw_message*(message: string) =
  echo terminal.red(message)
  quit(0)
  # raise newException(MessageError, message)


# Exception.message --------------------------------------------------------------------------------
func message*(e: Exception | ref Exception): string = e.msg


# copy.T -------------------------------------------------------------------------------------------
# Making the copy intention explicit
func copy*[T](o: T | ref T): T = o

# ensure -------------------------------------------------------------------------------------------
proc ensure*[V](v: V, check: (V) -> bool, message = "check failed"): V =
  if check(v): v else: throw(message)
proc ensure*[V](v: V, check: (V) -> bool, message: () -> string): V =
  if check(v): v else: throw(message())


# to_ref -------------------------------------------------------------------------------------------
proc to_ref*[T](o: T): ref T =
  result.new
  result[] = o


# to_shared_ptr ------------------------------------------------------------------------------------
proc to_shared_ptr*[T](v: T): ptr T =
  result = create_shared(T)
  result[] = v


# init ---------------------------------------------------------------------------------------------
proc init*[T](_: type[string], v: T): string = $v


# to -----------------------------------------------------------------------------------------------
template to*[F,T](f: F, _: type[T]): T = T.init(f)


# int.align ----------------------------------------------------------------------------------------
proc align*(n: int, digits: int): string = ($n).align(digits, '0')


# T.$ ----------------------------------------------------------------------------------------------
proc `$`*[T: typed](x: ref T): string = "->" & $(x[])


# p ------------------------------------------------------------------------------------------------
func p*(args: varargs[string, `$`]): void = debug_echo args.join(" ")


# string.error_type --------------------------------------------------------------------------------
# Extract error type from string message, the last part of `some text :some_type`
func error_type*(message: string): string =
  let error_type_re = nre.re("(?i).*\\s:([a-z0-9_-]+)$")
  if stdoptions.is_some(nre.match(message, error_type_re)): nre.split(message, nre.re("\\s:"))[^1]
  else:                                         ""

test "error_type":
  assert "No security definition has been found :not_found".error_type == "not_found"


# timer_sec ----------------------------------------------------------------------------------------
proc timer_sec*(): (proc (): int) =
  let started_at = nt.utc(nt.now())
  () => nt.in_seconds(nt.`-`(nt.utc(nt.now()), started_at)).int

proc timer_ms*(): (proc (): int) =
  let started_at = nt.utc(nt.now())
  () => nt.in_milliseconds(nt.`-`(nt.utc(nt.now()), started_at)).int