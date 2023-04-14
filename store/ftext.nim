import base, std/os

proc parse_ftext*(ftext: string): JsonNode =
  let blocks = ftext.find_all(re"[^\^]+\^[a-z][^\n]+").map(trim)
  echo blocks
  # some text ^list

slow_test "parse_ftext":
  let dirname = current_source_path().parent_dir
  let basics = fs.read dirname & "/ftext/basics.ft"
  discard parse_ftext(basics)