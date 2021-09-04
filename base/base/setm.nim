require sets

export setsm

# is_empty -----------------------------------------------------------------------------------------
func is_empty*[T](s: HashSet[T]): bool = s.len == 0
func is_blank*[T](s: HashSet[T]): bool = s.len == 0

func add*[T](s: var HashSet[T], v: T) =
  s.incl v