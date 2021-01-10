import supportm, typetraits

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
  assert o.is_some, message
  o.get


proc map*[T](self: Option[T], op: proc (v: T)): Option[T] =
  if self.isSome: op(self.value)

proc `$`*[T](self: Option[T]): string =
  if self.is_some:
    result = "Some("
    result.addQuoted self.value
    result.add ")"
  else:
    if self.message != "": "None(" & self.message & ")" else: "None"