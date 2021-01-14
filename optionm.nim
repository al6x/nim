import supportm, options

export options

proc ensure*[T](o: Option[T], message: string): T =
  if o.is_none: throw(message) else: o.get


proc apply*[T](o: Option[T], op: proc (v: T): void): void =
  if o.is_some: op(o.value)