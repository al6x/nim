import supportm, stringm


# T.field_names, o.field_names ---------------------------------------------------------------------
proc field_names*[T](o: T): seq[string] =
  var t: T
  for k, _ in t.field_pairs: result.add k

template field_names*[T](_: type[T]): seq[string] =
  var t: T; var names: seq[string]
  when t is ref object:
    for k, _ in t[].field_pairs: names.add k
  else:
    for k, _ in t.field_pairs: names.add k
  names


# to(bool) -----------------------------------------------------------------------------------------
proc to*(v: string, _: type[bool]): bool =
  case v.to_lower
  of "yes", "true", "t":  true
  of "no",  "false", "f": false
  else: throw fmt"invalid bool '{v}'"

proc to*(v: string, _: type[bool], default: bool): bool =
  if v == "": default else: v.to(bool)