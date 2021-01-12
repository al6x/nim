import typetraits
import supportm, jsonm

type
  Option*[T] = object
    case has: bool
    of false:
      message: string
    of true:
      value:   T

proc some*[T](v: T): Option[T] = Option[T](has: true, value: v)

proc none*(T: type): Option[T] = Option[T](has: false, message: "")

proc none*(T: type, message: string): Option[T] = Option[T](has: false, message: message)

proc none*[T]: Option[T] = none(T)


proc is_some*[T](self: Option[T]): bool {.inline.} = self.has

proc is_none*[T](self: Option[T]): bool {.inline.} = not self.is_some


proc get*[T](self: Option[T]): T =
  if self.is_none: throw("option is empty") else: self.value

proc get*[T](self: Option[T], otherwise: T): T =
  if self.is_none: otherwise else: self.value

proc get*[T](o: Option[T], otherwise: (proc (): T)): T =
  if o.is_some: o.get else: otherwise()


proc ensure*[T](o: Option[T], message: string): T =
  if o.is_none: throw(message)
  o.get


proc message*[T](o: Option[T]): string =
  assert o.is_none
  o.message

proc map*[T, R](self: Option[T], op: proc (v: T): R): Option[R] =
  if self.is_some: op(self.value).some
  else:            R.none(self.message)

proc `$`*[T](self: Option[T]): string =
  if self.is_some:
    result = "Some("
    result.addQuoted self.value
    result.add ")"
  else:
    result = if self.message != "": "None(" & self.message & ")" else: "None"

# json ---------------------------------------------------------------------------------------------
func `%`*[T](o: Option[T]): JsonNode =
  if o.is_some: %(o.value)
  else:         %nil

# func init_from_json*[T](dst: var Option[T], json: JsonNode, json_path: string) =
#   dst = init_from_json(json.get_str).some