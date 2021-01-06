import hashes

export hashes


# autohash -----------------------------------------------------------------------------------------
proc autohash*[T: tuple|object](o: T): Hash =
  var h: Hash = 0
  for f in o.fields: h = h !& f.hash
  !$h
