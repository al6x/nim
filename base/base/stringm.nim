import std/[re, strformat, options]
import std/strutils except `%`
import ./test

export strformat
export strutils except `%`

# LODO remove and use strutils.strip
proc trim*(s: string): string =
  s.replace(re("\\A[\\n\\s\\t]+|[\\n\\s\\t]+\\Z"), "")

test "trim":
  check:
    "".trim == ""
    " a b ".trim == "a b"
    " a \n b ".trim == "a \n b"


proc is_empty*(s: string): bool = s == ""


proc is_present*(s: string): bool = not s.is_empty


proc if_empty*(s: string, default: string): string =
  if s.is_empty: default else: s


proc take*(s: string, n: int): string =
  if n < s.len: s[0..(n - 1)] else: s

test "take":
  check:
    "abcd".take(2) == "ab"
    "ab".take(10) == "ab"


proc pluralize*(count: int, singular, plural: string): string =
  if count == 1: singular else: plural

proc pluralize*(count: int, singular: string): string =
  if count == 1: singular else: singular & "s"

test "pluralize":
  check:
    1.pluralize("second") == "second"
    2.pluralize("second") == "seconds"


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


proc format*(n: float | int, precision = 2): string =
  format_float(n, format = ff_decimal, precision = precision)

proc align*(n: int, digits: int): string = ($n).align(digits, '0')

# proc consume*(s: string, i: int, chars: set[char]): int =
#   let initial_i = i
#   var i = i
#   while i < s.len and s[i] in chars:
#     i += 1
#   i - initial_i

# proc consume*(s: string, i: int, c: char): int =
#   let initial_i = i
#   var i = i
#   while i < s.len and s[i] == c:
#     i += 1
#   i - initial_i

# proc continues_with*(s: string, chars: set[char], start: int): bool =
#   if start > s.high: return false
#   s[start] in chars

# proc match*(s: string, char: char, i: int): bool =

# proc match*(s: string, chars: set[char], i: int): bool =
#   var i = i
#   if i > s.high: return false
#   while i < s.len:
#     if s[i] notin chars: return false
#     i += 1
#   return true

# test "match":
#   check "abc".match({'c'}, 3)  == false
#   check "abc".match({'c'}, 2)  == true
#   check "abcd".match({'c'}, 2) == false

proc `len=`*(s: var string, n: int) =
  s.set_len n

proc fill*(_: type[string], len: int, c: char): string =
  result.len = len
  for i in 0..<len: result[i] = c

proc replace*(s: string, reps: openarray[(string, string)]): string =
  s.multi_replace(reps)