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


proc is_some*[T](o: Option[T]): bool {.inline.} = o.has

proc is_none*[T](o: Option[T]): bool {.inline.} = not o.is_some


proc get*[T](o: Option[T]): T =
  if o.is_none: throw("option is empty") else: o.value

proc get*[T](o: Option[T], otherwise: T): T =
  if o.is_none: otherwise else: o.value

proc get*[T](o: Option[T], otherwise: (proc (): T)): T =
  if o.is_some: o.get else: otherwise()


proc ensure*[T](o: Option[T], message: string): T =
  if o.is_none: throw(message) else: o.get


proc message*[T](o: Option[T]): string =
  assert o.is_none
  o.message


proc map*[T, R](o: Option[T], op: proc (v: T): R): Option[R] =
  if o.is_some: op(o.value).some else: R.none(o.message)


proc apply*[T](o: Option[T], op: proc (v: T): void): void =
  if o.is_some: op(o.value)


proc `==`*(a, b: Option): bool {.inline.} =
  (a.is_some and b.is_some and a.value == b.value) or (not a.is_some and not b.is_some)


proc `$`*[T](o: Option[T]): string =
  if o.is_some:
    result = "Some("
    result.addQuoted o.value
    result.add ")"
  else:
    result = if o.message != "": "None(" & o.message & ")" else: "None"


# json ---------------------------------------------------------------------------------------------
func `%`*[T](o: Option[T]): JsonNode =
  if o.is_some: %(o.value)
  else:         new_jnull()

func init_from_json*[T](dst: var Option[T], json: JsonNode, json_path: string) =
  if json != nil and json.kind != JNull:
    when T is ref:
      dst = some(new(T))
    else:
      dst = some(default(T))
    initFromJson(dst.get, json, json_path)
