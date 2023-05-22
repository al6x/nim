import base, mono/core, std/osproc
import ../core/spacem, ../ui/palette as pl

proc open_editor*(location: string, line = 1) =
  # LODO make editor configurable
  let cmd = fmt"code -g {location}:{line}"
  session.log.with((cmd: cmd)).info "edit"
  let output = exec_cmd_ex(command = cmd)
  if output.exit_code != 0: throw fmt"Can't open editor: '{cmd}'"

proc edit_btn*(location: string, line_n = 1): El =
  el(PIconButton, (icon: "edit", title: "Edit")):
    it.on_click proc = open_editor(location, line_n)

# proc open_editor*(self: FDoc, section: FSection) =
#   session.log.with((location: self.location)).info "edit section"
#   let output = exec_cmd_ex(command = fmt"code -g {self.location}:{section.line_n}")
#   if output.exit_code != 0: throw fmt"Can't exec fdoc section edit command"