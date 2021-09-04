require osproc

proc say*(text: string): void =
  try:    discard exec_process("say \"" & text & "\"")
  except: discard