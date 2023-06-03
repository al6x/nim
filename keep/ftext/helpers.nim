import base, mono/core, std/osproc, ext/url, ftext/[core, render]
import ../model/spacem, ../ui/palette as pl

proc build_ftext_context*(doc: FDoc, space_id: string): FContext =
  let mono_id = session.id
  proc ftext_image_path(path: string, context: FContext): string =
    let path = "/" & context.space_id & "/" & context.doc.id & "/" & path
    Url.init(path, { "mono_id": mono_id }).to_s

  let html_config = FHtmlConfig.init
  html_config.image_path = ftext_image_path

  (doc, space_id, html_config)

proc open_editor*(location: string, line = 1) =
  # LODO make editor configurable
  let cmd = fmt"code -g {location}:{line}"
  session.log.with((cmd: cmd)).info "edit"
  let output = exec_cmd_ex(command = cmd)
  if output.exit_code != 0: throw fmt"Can't open editor: '{cmd}'"

proc edit_btn*(location: string, line_n = 1): El =
  alter_el(el(PIconButton, (icon: "edit", title: "Edit"))):
    it.on_click proc = open_editor(location, line_n)

# proc open_editor*(self: FDoc, section: FSection) =
#   session.log.with((location: self.location)).info "edit section"
#   let output = exec_cmd_ex(command = fmt"code -g {self.location}:{section.line_n}")
#   if output.exit_code != 0: throw fmt"Can't exec fdoc section edit command"