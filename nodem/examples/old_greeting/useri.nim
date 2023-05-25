# Have to be generated manually, because of the circular dependency
import nodem
export nodem

let user* = Node("user")

proc user_name*(): Future[string] {.nimport_from: user.} = discard