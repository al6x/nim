import supportm, os, sugar, strutils, optionm

# open_file ----------------------------------------------------------------------------------------
proc open_file[T](path: string, ensure_parents: bool, mode: FileMode, cb: (proc (file: File): T)): T =
  var file: File
  var opened = file.open(path, mode)

  if ensure_parents:
    # If there's no parent dir - creating parent dirs and retrying opening
    if (not opened) and (not path.parent_dir.dir_exists):
      path.parent_dir.create_dir
      opened = file.open(path, mode)

  if opened:
    defer: file.close
    return cb(file)
  else:
    raise new_exception(IOError, "cannot open: " & path)


# read_file ----------------------------------------------------------------------------------------
proc read*(path: string): string =
  open_file(path, false, fm_read, (file) => file.read_all)


# read_file_optional -------------------------------------------------------------------------------
proc read_optional*(path: string): Option[string] =
  var file: File
  if file.open(path, fm_read):
    defer: file.close
    file.read_all.some
  else:
    string.none


# write_file ---------------------------------------------------------------------------------------
proc write*(path, data: string): void =
  discard open_file(path, true, fm_write, proc (file: auto): bool =
    file.write data
    false
  )


# append -------------------------------------------------------------------------------------------
proc append*(path, data: string): void =
  discard open_file(path, true, fm_append, proc (file: auto): bool =
    file.write data
    false
  )


# append_line --------------------------------------------------------------------------------------
proc append_line*(path, data: string): void =
  assert not("\n" in data), "appended line can't have newline characters"
  discard open_file(path, true, fm_append, proc (file: auto): bool =
    file.write "\n"
    file.write data
    false
  )


# Test ---------------------------------------------------------------------------------------------
# write_file("./tmp/some.txt", "some text")
# append_line("./tmp/some.txt", "line 1")
# append_line("./tmp/some.txt", "line 2")
# p read_file("./tmp/some.txt")
