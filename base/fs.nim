import ./supportm, os, sugar, strutils, ./optionm, strformat

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


# write --------------------------------------------------------------------------------------------
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


# exist --------------------------------------------------------------------------------------------
proc exist*(path: string): bool =
  try:
    discard get_file_info(path)
    true
  except:
    false


# is_empty_dir -------------------------------------------------------------------------------------
proc is_empty_dir(path: string): bool =
  for _ in walk_dir(path, relative = true, check_dir = false):
    return false
  true

# delete -------------------------------------------------------------------------------------------
# Deletes file or directory, does nothing if path not exist
proc delete*(path: string, recursive = false) =
  try:
    remove_file path
  except:
    if not path.exist:
      return
    elif path.is_empty_dir or recursive:
      remove_dir path
    else:
      assert path.dir_exists, "internal error, expecting directory to exist"
      throw fmt"can't delete not empty directory '{path}'"


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  write("./tmp/some.txt", "some text")
  append_line("./tmp/some.txt", "line 1")
  append_line("./tmp/some.txt", "line 2")
  echo read("./tmp/some.txt")
