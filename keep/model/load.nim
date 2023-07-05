import base, ext/watch_dir, ./schema, ./docm, ./dbm

type DocFileParser* = proc (path: string): Doc
type DocFileParsers* = ref Table[string, DocFileParser]

proc add_dir*(db: Db, space: Space, parsers: DocFileParsers, space_path: string) =
  unless fs.exist space_path: throw fmt"Space path don't exist: {space_path}"
  space.log.with((path: space_path)).info "load"

  # Loading
  for entry in fs.read_dir(space_path):
    if entry.kind == file: # and entry.path.ends_with(".ft"):
      let (name, ext) = entry.name.file_name_ext
      if ext in parsers:
        let parser = parsers[ext]
        let doc = parser(entry.path)
        assert doc.id == name, "doc id shall be same as file name"
        if doc.id in space.docs:
          space.warns.add fmt"Name conflict: {doc.id}"
        else:
          space.apdate doc

  # Watching files for chages
  let get_changed = watch_dir space_path
  proc check_for_changed_files =
    for entry in get_changed():
      if entry.kind == file:
        let rpath = entry.path.replace space_path & "/"
        let parts = rpath.split("/")
        if   parts.len == 1: # top level file in space
          let (name, ext) = rpath.file_name_ext
          if ext in parsers:
            let parser = parsers[ext]
            case entry.change
            of created, updated:
              let doc = parser(entry.path)
              assert doc.id == name, "doc id shall be same as file name"
              space.apdate doc
            of deleted:
              space.del name
            space.version.inc
            space.log.with((doc: entry.path.file_name)).info entry.change.to_s
        elif parts.len > 1: # file in space subdir
          let subdir = parts[0]
          if subdir in space.docs: # doc asset changed
            var doc = space.docs[subdir]
            let location = doc.source.DocTextSource.location
            let (name, ext) = location.file_name_ext
            if ext in parsers:
              let parser = parsers[ext]
              doc = parser(location)
              assert doc.id == name, "doc id shall be same as file name"
              space.apdate doc
              space.version.inc
              space.log.with((doc: location.file_name)).info "updated"
        else:
          throw "error"
  db.bgjobs.add check_for_changed_files