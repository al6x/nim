import std/[strutils]
import ./env as envm, ./check
from ./terminal as terminal import nil

export check, strutils

template print_test_info(slow: bool, filename, testname: string, failed: bool): void =
  const id_len = 7
  let fname = filename.split(".")[0]
  let ffname = fname.align_left(id_len)[0..(id_len-1)]
  let module = if slow: "stest" else: " test"
  if failed:
    echo terminal.red(" " & module & " | " & ffname & " " & testname & " failed")
  else:
    echo terminal.grey(" " & module & " | " & ffname & " " & testname)

template test*(name: string, body) =
  let test_variable = env["test", "false"]
  if test_variable == "true" or test_variable == "fast" or test_variable == name:
    let pos = instantiation_info()
    print_test_info(false, pos.filename, name, false)
    try:
      body
    except Exception as e:
      print_test_info(false, pos.filename, name, true)
      quit e.msg

template slow_test*(name: string, body) =
  let test_variable = env["test", "false"]
  if test_variable == "true" or test_variable == name:
    print_test_info(true, pos.filename, name, false)
    try:
      body
    except Exception as e:
      print_test_info(true, pos.filename, name, true)
      quit e.msg

if is_main_module:
  test "some":
    echo "testing"