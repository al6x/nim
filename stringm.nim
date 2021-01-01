import ./supportm, re

# string.trim --------------------------------------------------------------------------------------
func trim*(s: string): string =
  s.replace(re("\\A[\\n\\s\\t]|[\\n\\s\\t]\\Z"), "")

test "trim":
  assert "".trim == ""
  assert " a b ".trim == "a b"
  assert " a \n b ".trim == "a \n b"
