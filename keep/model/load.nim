import base, ext/[vcache, watch_dir], ./docm, ./spacem, ./dbm

type DocFileParser* = proc (path: string): Doc
type DocFileParsers* = ref Table[string, DocFileParser]

proc post_process_doc(doc: Doc, fname: string, space: Space) =
  assert doc.id == fname, "doc id shall be same as file name"

  # Merging and normalising tags
  doc.ntags = (doc.tags.map(to_lower) & space.ntags).sort
  for blk in doc.blocks:
    blk.ntags = (blk.tags.map(to_lower) & doc.ntags).sort

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
        let (name, ext) = entry.path.file_name_ext
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
  db.bgjobs.add check_for_changed_files