import basem, jsonm


# call ---------------------------------------------------------------------------------------------
proc call*[T](call: string, args: T, state = false): string =
  (call: call, args: args, state: state).to_json(false)
proc call*(call: string, state = false): string =
  (call: call, state: state).to_json(false)