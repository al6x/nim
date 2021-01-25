import supportm, optionm, sugar, tablem

type E*[T] = object
  case is_error*: bool
  of true:
    message*: string
  of false:
    value*: T


func is_success*[T](e: E[T]): bool = not e.is_error


func get*[T](e: E[T]): T =
  if e.is_error: throw(e.message) else: e.value


func error*(T: type, message: string): E[T] = E[T](is_error: true, message: message)


func success*[T](value: T): E[T] = E[T](is_error: false, value: value)


func success*[T](value: Option[T]): E[T] = E[T](is_error: false, value: value.get)


# Used in `a.to(E[B])` conversions
proc init*[B, A](_: type[E[B]], a: E[A]): E[B] =
  assert a.is_error, "init possible for errors only"
  B.error(a.message)

test "init":
  discard E[string].init(int.error("some error"))
  discard int.error("some error").to(E[float])


func errors*[T](list: seq[E[T]]): seq[string] =
  list.filter_map(proc (e: E[T]): auto =
    if e.is_error: e.message.some else: string.none
  )

func errors*[K, V](table: Table[K, E[V]] | ref Table[K, E[V]]): Table[K, string] =
  table.filter_map(proc (e: E[V]): auto =
    if e.is_error: e.message.some else: string.none
  )


func successes*[T](list: seq[E[T]]): seq[T] =
  list.filter_map(proc (e: E[T]): auto =
    if e.is_error: T.none else: e.value.some
  )

func successes*[K, V](table: Table[K, E[V]] | ref Table[K, E[V]]): Table[K, V] =
  table.filter_map(proc (e: E[V]): auto =
    if e.is_error: V.none else: e.value.some
  )


proc map*[A, B](a: E[A], op: (A) -> B): E[B] =
  if a.is_success: op(a.get).success else: B.error(a.message)