import ./supportm, os, sugar, strutils, ./optionm, strformat

type FS* = object
const fs* = FS()


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


proc move*(fs: FS, source, dest: string, ensure_parents = true): void =
  try:
    move_file(source, dest)
  except Exception as e:
    if ensure_parents and not dest.parent_dir.dir_exists:
      dest.parent_dir.create_dir
      move_file(source, dest)
    else:
      raise new_exception(IOError, fmt"cannot move: {source} to {dest}, {e.msg}")


proc read*(fs: FS, path: string): string =
  open_file(path, false, fm_read, (file) => file.read_all)


proc read_optional*(fs: FS, path: string): Option[string] =
  var file: File
  if file.open(path, fm_read):
    defer: file.close
    file.read_all.some
  else:
    string.none


proc write*(fs: FS, path, data: string): void =
  discard open_file(path, true, fm_write, proc (file: auto): bool =
    file.write data
    false
  )


proc append*(fs: FS, path, data: string): void =
  discard open_file(path, true, fm_append, proc (file: auto): bool =
    file.write data
    false
  )


proc append_line*(fs: FS, path, data: string): void =
  assert not("\n" in data), "appended line can't have newline characters"
  discard open_file(path, true, fm_append, proc (file: auto): bool =
    file.write "\n"
    file.write data
    false
  )


proc exist*(fs: FS, path: string): bool =
  try:
    discard get_file_info(path)
    true
  except:
    false


proc is_empty_dir(fs: FS, path: string): bool =
  for _ in walk_dir(path, relative = true):
    return false
  true


proc delete*(fs: FS, path: string, recursive = false, delete_empty_parents = false) =
  # Deletes file or directory, does nothing if path not exist
  try:
    remove_file path
  except:
    if not fs.exist path:
      return
    elif fs.is_empty_dir(path) or recursive:
      remove_dir path
    else:
      assert dir_exists(path), "internal error, expecting directory to exist"
      throw fmt"can't delete not empty directory '{path}'"

  if delete_empty_parents and fs.is_empty_dir(path.parent_dir):
    fs.delete(path.parent_dir, recursive = false, delete_empty_parents = true)


# Test ---------------------------------------------------------------------------------------------

if is_main_module:
  fs.write("./tmp/fs/some.txt", "some text")
  fs.append_line("./tmp/fs/some.txt", "line 1")
  fs.append_line("./tmp/fs/some.txt", "line 2")
  echo fs.read("./tmp/fs/some.txt")
  fs.move("./tmp/fs/some.txt", "./tmp/fs/some_dir/some.text")
  fs.delete("./tmp/some_dir/some.text", delete_empty_parents = true)

  # var list = ""
  # for path in walk_dir("./tmp/fs", relative = true):
  #   # pcFile,               ## path refers to a file
  #   # pcLinkToFile,         ## path refers to a symbolic link to a file
  #   # pcDir,                ## path refers to a directory
  #   # pcLinkToDir           ## path refers to a symbolic link to a directory

  #   p path
