require std/[options, sugar]
require ./support

export optionsm except option


func ensure*[T](o: Option[T], message: string): T =
  if o.is_none: throw(message) else: o.get

func ensure*[T](o: Option[T], message: () -> string): T =
  if o.is_none: throw(message()) else: o.get


func apply*[T](o: Option[T], op: (T) -> void): void =
  if o.is_some: op(o.value)


func is_empty*[T](o: Option[T]): bool {.inline.} = o.is_none
func is_blank*[T](o: Option[T]): bool {.inline.} = o.is_none
func is_present*[T](o: Option[T]): bool {.inline.} = o.is_some

# proc set*[T](v: T): Option[T] {.inline.} = v.some


proc get*[T](o: Option[T], otherwise: () -> T): T =
  if o.is_some: o.get else: otherwise()

proc clean*[T](o: var Option[T]): void =
  o = T.none

# converter to_option*[T: string | int | float | bool](v: T): Option[T] =
#   v.some