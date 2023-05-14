import std/posix, base, ./async

proc file_mtime_as_unix_epoch*(path: string): int =
  let fd = open(path, CS_PATH)
  var s: Stat
  if fstat(cint fd, s) != 0:
    throw fmt"can't get file stats, can't open file descriptor for '{path}', errno {errno}"
  result = int s.st_mtime
  if close(fd) != 0:
    throw fmt"can't get file stats, can't close file descriptor for '{path}', errno {errno}"
  # rewrite with getFileInfo

type Stats = Table[string, tuple[kind: FSEntryKind, mtime: int]]
proc read_tree_stats(stats: var Stats, path: string, hidden = false) =
  for entry in fs.read_dir(path, hidden = hidden):
    if entry.kind == file:
      stats[entry.path] = (entry.kind, file_mtime_as_unix_epoch(entry.path))
    else:
      read_tree_stats(stats, entry.path, hidden = hidden)

type
  ChangeKind* = enum created, updated, deleted
  Change* = object
    path*:   string
    kind*:   FsEntryKind
    change*: ChangeKind

proc watch_dir*(path: string, hidden = false): proc: seq[Change] =
  # Checks for changed files, slow.
  # Could be used with async, but it's going to be slow as IO will be sync.
  var old_stats = Stats()
  read_tree_stats(old_stats, path, hidden = hidden)

  proc: seq[Change] =
    var stats = Stats()
    read_tree_stats(stats, path, hidden = hidden)
    for path, (entry_kind, mtime) in stats:
      if path notin old_stats:
        result.add Change(path: path, kind: entry_kind, change: created)
      elif mtime != old_stats[path].mtime:
        result.add Change(path: path, kind: entry_kind, change: updated)
    for path, (entry_kind, mtime) in old_stats:
      if path notin stats:
        result.add Change(path: path, kind: entry_kind, change: deleted)
    old_stats = stats

proc watch_dir*(path: string, on_change: (proc (c: seq[Change])), hidden = false, interval_ms = 200) =
  let get_changed = watch_dir(path, hidden = hidden)
  add_timer(interval_ms, () => on_change(get_changed()), once = false)

when is_main_module:
  let diff = watch_dir("./base")
  while true:
    discard sleep(1)
    diff().p