import options

export options

# get ----------------------------------------------------------------------------------------------
proc get*[T](o: Option[T], otherwise: (proc (): T)): T =
  if o.is_some: o.get else: otherwise()


# ensure -------------------------------------------------------------------------------------------
proc ensure*[T](o: Option[T], message: string): T =
  assert o.is_some, message
  o.get
