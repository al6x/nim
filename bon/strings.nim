import ./support, re

# string.trim --------------------------------------------------------------------------------------
func trim*(s: string): string =
  s.replace(re("^[\\n\\s\\t]|[\\n\\s\\t]$"), "")

test "trim":
  assert "".trim == ""
  assert " a b ".trim == "a b"
