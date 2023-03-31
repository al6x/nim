import std/[strutils]
import ./env as envm, ./check
from ./terminal as terminal import nil

export check, strutils

template test*(name: string, body) =
  let test_variable = env["test", "false"]
  if test_variable == "true" or test_variable == "fast" or test_variable == name:
    let pos = instantiation_info()
    let fname = pos.filename.split(".")[0]
    let ffname = fname.align_left(7)[0..6]
    echo terminal.grey("  test | " & ffname & " " & name)
    try:
      body
    except Exception as e:
      echo terminal.red("  test | " & name & " failed")
      quit e.msg

template slow_test*(name: string, body) =
  let test_variable = env["test", "false"]
  if test_variable == "true" or test_variable == name:
    let pos = instantiation_info()
    let fname = pos.filename.split(".")[0]
    let ffname = fname.align_left(7)[0..6]
    echo terminal.grey("  test | " & ffname & " " & name)
    try:
      body
    except Exception as e:
      echo terminal.red("  test | " & name & " failed")
      quit e.msg

if is_main_module:
  test "some":
    echo "testing"