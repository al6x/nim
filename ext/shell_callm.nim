import osproc, jsonm, stringm, falliblem

type ShellArg[B, I, A] = object
  before: B
  inputs: seq[I]
  after:  A

let json_output_token = "shell_call_json_output:"
proc shell_calls*[B, I, A, R](command: string, before: B, inputs: seq[I], after: A): seq[Fallible[R]] =
  let shell_arg = ShellArg[B, I, A](before: before, inputs: inputs, after: after)
  let shell_arg_json = $(shell_arg.to_json)
  let escaped_shell_arg_json = shell_arg_json.replace("\"", "\\\"")
  let cmd = command & " \"" & escaped_shell_arg_json & "\""
  let full_output = exec_cmd_ex(cmd).output

  # Programs can print to stdout, ignoring such output
  assert json_output_token in full_output,
    "shell call output should contain token '{" & json_output_token & "}'"
  let json_output = full_output.split(json_output_token).last

  let parsed_json = json_output.parse_json
  for edata in parsed_json.items:
    result.add if edata["is_error"].get_bool:
      R.error edata["error"].get_str
    else:
      try:
        edata["value"].to_json(R).success
      except Exception as e:
        R.error fmt"can't parse {$(R.typeof)} json, {e}"

proc shell_call*[B, I, A, R](command: string, before: B, input: I, after: A): Fallible[R] =
  shell_calls[B, I, A, R](command, before, @[input], after)[0]