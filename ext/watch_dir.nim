import std/posix, base

proc file_mtime_as_unix_epoch*(path: string): int =
  let fd = open(path, CS_PATH)
  var s: Stat
  if fstat(cint fd, s) != 0:
    throw fmt"can't get file stats, can't open file descriptor for '{path}', errno {errno}"
  result = int s.st_mtime
  if close(fd) != 0:
    throw fmt"can't get file stats, can't close file descriptor for '{path}', errno {errno}"

type Stats = Table[string, int]
proc read_tree_stats(stats: var Stats, path: string, hidden = false) =
  for entry in fs.read_dir(path, hidden = hidden):
    let epath = path & "/" & entry.name
    if entry.kind == file or entry.kind == file_link:
      stats[epath] = file_mtime_as_unix_epoch epath
    else:
      read_tree_stats(stats, epath, hidden = hidden)

type
  ChangeKind* = enum created, updated, deleted
  Change* = object
    path*: string
    kind*: ChangeKind

proc watch_dir*(path: string, hidden = false): proc: seq[Change] =
  var old_stats = Stats()
  read_tree_stats(old_stats, path, hidden = hidden)

  proc: seq[Change] =
    var stats = Stats()
    read_tree_stats(stats, path, hidden = hidden)
    for path, mtime in stats:
      if path notin old_stats:
        result.add Change(path: path, kind: created)
      elif mtime != old_stats[path]:
        result.add Change(path: path, kind: updated)
    for path, mtime in old_stats:
      if path notin stats:
        result.add Change(path: path, kind: deleted)
    old_stats = stats

when is_main_module:
  let diff = watch_dir("./base")
  while true:
    discard sleep(1)
    diff().p