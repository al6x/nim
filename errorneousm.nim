import supportm

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
