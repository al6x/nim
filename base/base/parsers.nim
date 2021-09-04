require ./[support, string]


# T.field_names, o.field_names ---------------------------------------------------------------------
proc field_names*[T](o: T): seq[string] =
  for k, _ in o.field_pairs: result.add k
  result.sort

proc field_names*[T](o: ref T): seq[string] =
  o[].field_names

# template field_names*[T](_: type[T]): seq[string] =
#   var t: T # won't work for variant, as the default variant will be created
#   var names: seq[string]
#   when t is ref object:
#     for k, _ in t[].field_pairs: names.add k
#   else:
#     for k, _ in t.field_pairs: names.add k
#   names


# to(bool) -----------------------------------------------------------------------------------------
proc to*(v: string, _: type[bool]): bool =
  case v.to_lower
  of "yes", "true", "t":  true
  of "no",  "false", "f": false
  else: throw fmt"invalid bool '{v}'"

proc to*(v: string, _: type[bool], default: bool): bool =
  if v == "": default else: v.to(bool)