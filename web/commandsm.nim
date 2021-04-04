import basem, jsonm


# action -------------------------------------------------------------------------------------------
proc action*[T](action: string, args: T, state = false): string =
  (action: "/" & action, args: args, state: state).to_json(false)

proc action*(action: string, state = false): string =
  (action: "/" & action, state: state).to_json(false)