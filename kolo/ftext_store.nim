import base, ext/[async, watch_dir], std/os
import ./store, ./ftext
# import ./ftext except FBlock, FDoc

type SFDoc* = ref object of Doc
  fdoc*: FDoc

proc init*(_: type[SFDoc], src: FDoc): SFDoc =
  let version = src.hash.int
  result = SFDoc(id: src.location, title: src.title, version: version, fdoc: src, warnings: src.warnings)
  for section_i, ssection in src.sections:
    result.blocks.add Block(
      id:       fmt"{section_i}",
      version:  version,
      tags:     ssection.tags & src.tags,
      text:     ssection.title,
      warnings: ssection.warnings
    )
    for block_i, sblock in ssection.blocks:
      result.blocks.add Block(
        id:       fmt"{section_i}/{block_i}",
        version:  version,
        tags:     sblock.tags & ssection.tags & src.tags,
        links:    sblock.links,
        glinks:   sblock.glinks,
        text:     sblock.text,
        warnings: sblock.warnings
      )

proc add_ftext_dir*(space: Space, path: string) =
  proc load(fpath: string): SFDoc =
    let parsed = parse_ftext(fs.read(fpath), fpath.file_name)
    result = SFDoc.init parsed
    assert result.id == fpath.file_name

  for entry in fs.read_dir(path):
    if entry.kind == file and entry.path.ends_with(".ft"):
      let fdoc = load entry.path
      if fdoc.id in space.docs:
        space.warnings.add fmt"name conflict: '{fdoc.id}'"
      else:
        space.docs[fdoc.id] = fdoc
  space.version = 0
  p "re-run checks on doc"

  proc on_change(changes: seq[Change]) =
    for entry in changes:
      if entry.kind == file and entry.path.ends_with(".ft"):
        case entry.change
        of created, updated:
          let fdoc = load entry.path
          space.docs[fdoc.id] = fdoc
        of deleted:
          space.docs.del entry.path.file_name
        space.version.inc
    p "re-run checks on doc"
  watch_dir(path, on_change)

if is_main_module:
  let project_dir = current_source_path().parent_dir.absolute_path
  let space = Space.init(name = "test_space")
  space.add_ftext_dir fmt"{project_dir}/test/ftext_store"
  p space