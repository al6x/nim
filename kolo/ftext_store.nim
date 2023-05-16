import base, ext/[async, watch_dir], std/os
import ./[space, ftext]

type FDocHead* = ref object of Doc
  doc*: FDoc

proc init*(_: type[FDocHead], doc: FDoc): FDocHead =
  let version = doc.hash.int
  result = FDocHead(id: doc.location, title: doc.title, version: version, doc: doc, warnings: doc.warnings)
  for section_i, ssection in doc.sections:
    result.blocks.add Block(
      id:       fmt"{section_i}",
      version:  version,
      tags:     ssection.tags & doc.tags,
      text:     ssection.title,
      warnings: ssection.warnings
    )
    for block_i, sblock in ssection.blocks:
      result.blocks.add Block(
        id:       fmt"{section_i}/{block_i}",
        version:  version,
        tags:     sblock.tags & ssection.tags & doc.tags,
        links:    sblock.links,
        glinks:   sblock.glinks,
        text:     sblock.text,
        warnings: sblock.warnings
      )

proc add_ftext_dir*(space: Space, path: string) =
  proc load(fpath: string): FDocHead =
    let parsed = parse_ftext(fs.read(fpath), fpath.file_name)
    result = FDocHead.init parsed
    assert result.id == fpath.file_name

  # Loading
  for entry in fs.read_dir(path):
    if entry.kind == file and entry.path.ends_with(".ft"):
      let fdoc = load entry.path
      if fdoc.id in space.docs:
        space.warnings.add fmt"name conflict: '{fdoc.id}'"
      else:
        space.docs[fdoc.id] = fdoc
  space.version = 0
  # space.check

  # Watching files for chages
  let get_changed = watch_dir path
  proc check_for_changed_files =
    for entry in get_changed():
      if entry.kind == file and entry.path.ends_with(".ft"):
        case entry.change
        of created, updated:
          let fdoc = load entry.path
          space.docs[fdoc.id] = fdoc
          # space.check fdoc.id
        of deleted:
          space.docs.del entry.path.file_name
        space.version.inc
  space.bgprocesses.add ("check_for_changed_files", check_for_changed_files)

# test ---------------------------------------------------------------------------------------------
if is_main_module:
  let project_dir = current_source_path().parent_dir.absolute_path
  let space = Space.init(name = "test_space")
  space.add_ftext_dir fmt"{project_dir}/test/ftext_store"
  p space