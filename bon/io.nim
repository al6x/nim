import ./support, parsecsv

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