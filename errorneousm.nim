import supportm, optionm, sugar, tablem

type Errorneous*[T] = object
  case is_error*: bool
  of true:
    error*: string
  of false:
    value*: T

func get*[T](e: Errorneous[T]): T =
  if e.is_error: throw(e.error) else: e.value

func failure*(T: type, error: string): Errorneous[T] = Errorneous[T](is_error: true, error: error)

func success*[T](value: T): Errorneous[T] = Errorneous[T](is_error: false, value: value)

func success*[T](value: Option[T]): Errorneous[T] = Errorneous[T](is_error: false, value: value.get)

func failures*[T](list: seq[Errorneous[T]]): seq[string] =
  list.filter_map(proc (e: Errorneous[T]): auto =
    if e.is_error: e.error.some else: string.none
  )

func failures*[K, V](table: Table[K, Errorneous[V]] | ref Table[K, Errorneous[V]]): Table[K, string] =
  table.filter_map(proc (e: Errorneous[V]): auto =
    if e.is_error: e.error.some else: string.none
  )


func successes*[T](list: seq[Errorneous[T]]): seq[T] =
  list.filter_map(proc (e: Errorneous[T]): auto =
    if e.is_error: T.none else: e.value.some
  )


func successes*[K, V](table: Table[K, Errorneous[V]] | ref Table[K, Errorneous[V]]): Table[K, V] =
  table.filter_map(proc (e: Errorneous[V]): auto =
    if e.is_error: V.none else: e.value.some
  )