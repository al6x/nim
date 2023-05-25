import std/[os, sugar, strutils, strformat]
import ./support, ./option, ./enumm

type FS* = object
const fs* = FS()

export parent_dir

proc file_name*(path: string): string =
  path.last_path_part

proc file_name_ext*(path: string): tuple[name, ext: string] =
  let parts = path.last_path_part.rsplit('.', maxsplit = 1)
  (parts[0], parts[1])

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


type FsEntryKind* = enum file, dir
type FsEntry* = tuple[kind: FsEntryKind, name, path: string]

proc read_dir*(fs: FS, path: string, hidden = false): seq[FsEntry] =
  for entry in walk_dir(path, relative = true):
    let kind =
      case entry.kind
      of pcFile:       FsEntryKind.file
      of pcLinkToFile: FsEntryKind.file
      of pcDir:        FsEntryKind.dir
      of pcLinkToDir:  FsEntryKind.dir
    if hidden or not entry.path.starts_with("."):
      result.add (kind, entry.path, path & "/" & entry.path)




# type FsEntryKind* = enum file, file_link, dir, dir_link
# # autoconvert FsEntryKind

# type FsEntry* = tuple[kind: FsEntryKind, path: string]

# proc read_dir*(fs: FS, path: string, hidden = false): seq[FsEntry] =
#   for entry in walk_dir(path, relative = true):
#     let kind =
#       case entry.kind
#       of pcFile:       FsEntryKind.file
#       of pcLinkToFile: FsEntryKind.file_link
#       of pcDir:        FsEntryKind.dir
#       of pcLinkToDir:  FsEntryKind.dir_link
#     if hidden or not entry.path.starts_with("."):
#       result.add (kind, path & "/" & entry.path)


proc is_empty_dir*(fs: FS, path: string): bool =
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
  echo fs.read_dir("./tmp")
  fs.move("./tmp/fs/some.txt", "./tmp/fs/some_dir/some.text")
  fs.delete("./tmp/some_dir/some.text", delete_empty_parents = true)
  echo "./tmp/fs/some.txt".file_name_ext
  echo "some.txt.zip".file_name_ext

  # var list = ""
  # for path in walk_dir("./tmp/fs", relative = true):
  #   # pcFile,               ## path refers to a file
  #   # pcLinkToFile,         ## path refers to a symbolic link to a file
  #   # pcDir,                ## path refers to a directory
  #   # pcLinkToDir           ## path refers to a symbolic link to a directory

  #   p path
