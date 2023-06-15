import ./hashes

export hashes


# autohash -----------------------------------------------------------------------------------------
proc autohash*[T: tuple|object](o: T): Hash =
  result = 0
  for f in o.fields: result = result !& f.hash
  result = !$result

proc autohash*[T: ref object](o: T): Hash =
  result = 0
  for f in o[].fields: result = result !& f.hash
  result = !$result
