import std/[re, strformat]
import std/strutils except `%`
import ./support

export strformat
export strutils except `%`


func trim*(s: string): string =
  s.replace(re("\\A[\\n\\s\\t]|[\\n\\s\\t]\\Z"), "")

test "trim":
  assert "".trim == ""
  assert " a b ".trim == "a b"
  assert " a \n b ".trim == "a \n b"


proc is_empty*(s: string): bool = s == ""


proc is_present*(s: string): bool = not s.is_empty


proc if_empty*(s: string, default: string): string =
  if s.is_empty: default else: s


proc take*(s: string, n: int): string =
  if n < s.len: s[0..(n - 1)] else: s

test "take":
  assert "abcd".take(2) == "ab"
  assert "ab".take(10) == "ab"


proc pluralize*(count: int, singular, plural: string): string =
  if count == 1: singular else: plural

proc pluralize*(count: int, singular: string): string =
  if count == 1: singular else: singular & "s"

test "pluralize":
  assert 1.pluralize("second") == "second"
  assert 2.pluralize("second") == "seconds"


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