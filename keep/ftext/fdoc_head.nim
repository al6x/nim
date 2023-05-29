import base, ext/[async, watch_dir]
import ../core/spacem, ftext/parse

type FDocHead* = ref object of Doc
  doc*: FDoc

proc init*(_: type[FDocHead], doc: FDoc): FDocHead =
  let version = doc.hash.int
  let did = doc.location.file_name_ext.name
  result = FDocHead(id: did, title: doc.title, version: version, doc: doc, warns: doc.warns, tags: doc.tags)
  for section_i, ssection in doc.sections:
    result.blocks.add Block(
      id:      fmt"{section_i}",
      version: version,
      tags:    ssection.tags & doc.tags,
      text:    ssection.title,
      warns:   ssection.warns
    )
    for block_i, sblock in ssection.blocks:
      result.blocks.add Block(
        id:      fmt"{section_i}/{block_i}",
        version: version,
        tags:    sblock.tags & ssection.tags & doc.tags,
        links:   sblock.links,
        glinks:  sblock.glinks,
        text:    sblock.text,
        warns:   sblock.warns
      )

proc add_ftext_dir*(space: Space, space_path: string) =
  unless fs.exist space_path: throw fmt"Space path don't exist: {space_path}"

  space.log.with((path: space_path)).info "load"
  proc load(fpath: string): FDocHead =
    let parsed = FDoc.read fpath
    result = FDocHead.init parsed
    assert result.id == fpath.file_name_ext.name

  # Loading
  for entry in fs.read_dir(space_path):
    if entry.kind == file and entry.path.ends_with(".ft"):
      let fdoc = load entry.path
      if fdoc.id in space.docs:
        space.warnings.add fmt"name conflict: '{fdoc.id}'"
      else:
        space.docs[fdoc.id] = fdoc
  space.version.inc

  # Watching files for chages
  let get_changed = watch_dir space_path
  proc check_for_changed_files =
    for entry in get_changed():
      if entry.kind == file and entry.path.ends_with(".ft"):
        case entry.change
        of created, updated:
          let fdoc = load entry.path
          space.docs[fdoc.id] = fdoc
        of deleted:
          space.docs.del entry.path.file_name
        space.log.with((doc: entry.path.file_name)).info "change"
        space.version.inc
  space.bgjobs.add check_for_changed_files

# test ---------------------------------------------------------------------------------------------
when is_main_module:
  import std/os
  let ftext_dir = current_source_path().parent_dir.absolute_path
  let space = Space.init(id = "test_space")
  space.add_ftext_dir fmt"{ftext_dir}/test"
  p space