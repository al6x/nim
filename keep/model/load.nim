import base, ext/watch_dir, ./docm, ./spacem, ./dbm

type DocFileParser* = proc (path: string): Doc
type DocFileParsers* = ref Table[string, DocFileParser]

proc post_process_doc(doc: Doc, fname: string, space: Space) =
  assert doc.id == fname, "doc id shall be same as file name"

  # Merging and normalising tags
  let doc_ntags = (doc.tags.map(to_lower) & space.ntags).sort
  for blk in doc.blocks:
    let block_ntags = blk.tags.map(to_lower)
    blk.ntags = (block_ntags & doc_ntags).unique.sort
    doc.ntags.add block_ntags
  doc.ntags = doc.ntags.unique.sort

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
        post_process_doc(doc, name, space)
        if doc.id in space.docs:
          space.warnings.add fmt"name conflict: {doc.id}"
        else:
          space.docs[doc.id] = doc
  space.version.inc

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
              post_process_doc(doc, name, space)
              space.docs[doc.id] = doc
            of deleted:
              space.docs.del name
            space.version.inc
            space.log.with((doc: entry.path.file_name)).info entry.change.to_s
        elif parts.len > 1: # file in space subdir
          let subdir = parts[0]
          if subdir in space.docs: # doc asset changed
            var doc = space.docs[subdir]
            let location = doc.source.DocTextSource.location
            let (name, ext) = location.file_name_ext
            let parser = parsers[ext]
            doc = parser(location)
            post_process_doc(doc, name, space)
            space.docs[doc.id] = doc
            space.version.inc
            space.log.with((doc: location.file_name)).info "updated"
        else:
          throw "error"
  db.bgjobs.add check_for_changed_files