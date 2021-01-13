import supportm, parsecsv, strutils, optionm, sugar

# map_csv ------------------------------------------------------------------------------------------
proc map_csv*[T](
  csv_file_path: string,
  map: proc(
    row: proc(key: string): string
  ): T
): seq[T] =
  var parser: CsvParser
  try:
    parser.open csv_file_path
    parser.read_header_row
    while parser.read_row:
      proc row(key: string): string =
        if key in parser.headers:
          parser.row_entry key
        else:
          throw fmt"unknown CSV row '{key}'"
      result.add map row
  finally:
    parser.close
  result


# to_csv -------------------------------------------------------------------------------------------
proc to_csv(
  rows:       seq[seq[string]],
  header:     Option[seq[string]] = seq[string].none,
  delimiter:  string
): string =
  var buff: seq[string]
  var ncolumns = if header.is_some: header.get.len
  else:
    assert rows.len > 0, "can't write empty CSV"
    rows[0].len

  if header.is_some: buff.add header.get.join(delimiter)
  for row in rows: buff.add row.join(delimiter)
  buff.join("\n")

proc to_csv*(
  rows:       seq[seq[string]],
  delimiter = ","
): string = to_csv(rows, seq[string].none, delimiter)

proc to_csv*(
  rows:       seq[seq[string]],
  header:     seq[string],
  delimiter = ","
): string = to_csv(rows, header.some, delimiter)

test "to_csv":
  let header = @["name", "value"]
  let rows = @[
    @["a", "1"],
    @["b", "2"]
  ]
  assert rows.to_csv(header) == "name,value\n" & "a,1\n" & "b,2"