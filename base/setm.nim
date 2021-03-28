import sets

export sets

# is_empty -----------------------------------------------------------------------------------------
func is_empty*[T](s: HashSet[T]): bool {.inline.} = s.len == 0
func is_blank*[T](s: HashSet[T]): bool {.inline.} = s.len == 0