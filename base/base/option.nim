import std/[options, sugar]
# import ./support,

export options except option

template throw(message: string) = raise Exception.new_exception(message)

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

proc getset*[T](o: var Option[T], v: T): T =
  if o.is_none:
    o = v.some
  o.get

proc get*[T](o: Option[T], otherwise: () -> T): T =
  if o.is_some: o.get else: otherwise()

proc clear*[T](o: var Option[T]): void =
  o = T.none

proc `==`*[T](a: Option[T], b: T): bool =
  a.is_some and a.get == b
proc `==`*[T](a: T, b: Option[T]): bool =
  b.is_some and b.get == a

proc contains*[T](s: seq[T] | set[T], v: Option[T]): bool =
  v.is_some and s.contains(v.get)

when is_main_module:
  assert "a".some == "a" and "a" == "a".some
  assert 'a'.some in {'a'} and 'a' in @['a']
  assert (case 'a'
    of {'a'}: 1
    else:     2
  ) == 1