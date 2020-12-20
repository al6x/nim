import ./support, os, options

proc read_file*(path: string): string =
  var file: File
  if file.open(path):
    defer: file.close
    file.read_all
  else:
    raise new_exception(IOError, "cannot open: " & path)

proc read_file_optional*(path: string): Option[string] =
  var file: File
  if file.open(path):
    defer: file.close
    file.read_all.some
  else:
    string.none

proc write_file*(path, content: string): void =
  var file: File
  var opened = file.open(path, fmWrite)

  # If there's no parent dir - creating parent dirs and retrying opening
  if (not opened) and (not path.parent_dir.exists_dir):
    path.parent_dir.create_dir
    opened = file.open(path, fmWrite)

  if opened:
    defer: file.close
    file.write content
  else:
    raise new_exception(IOError, "cannot open: " & path)