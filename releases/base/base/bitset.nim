import std/setutils

export setutils

proc to_bitset*[T](list: openarray[T]): set[T] =
  for v in list: result.incl v