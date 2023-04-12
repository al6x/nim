import std/[strformat, options]


# T.field_names, o.field_names ---------------------------------------------------------------------
proc field_names*[T](o: T): seq[string] =
  for k, _ in o.field_pairs: result.add k
  result.sort

# proc field_names*[T](o: ref T): seq[string] =
#   o[].field_names

# template field_names*[T](_: type[T]): seq[string] =
#   var t: T # won't work for variant, as the default variant will be created
#   var names: seq[string]
#   when t is ref object:
#     for k, _ in t[].field_pairs: names.add k
#   else:
#     for k, _ in t.field_pairs: names.add k
#   names


# to(bool) -----------------------------------------------------------------------------------------
# proc to*(v: string, _: type[bool]): bool =
#   case v.to_lower
#   of "yes", "true", "t":  true
#   of "no",  "false", "f": false
#   else: raise Exception.new_exception(fmt"invalid bool '{v}'")

# proc to*(v: string, _: type[bool], default: bool): bool =
#   if v == "": default else: v.to(bool)


# parse --------------------------------------------------------------------------------------------
proc parse*(_: type[int],    v: string): int    = v.parse_int
proc parse*(_: type[float],  v: string): float  = v.parse_float
proc parse*(_: type[string], v: string): string = v
proc parse*(_: type[bool],   v: string): bool   =
  if   v == "true":  true
  elif v == "false": false
  else:              v.to_lower in ["true", "t", "yes", "y", "on", "1"]
proc parse*[T](_: type[Option[T]], v: string): Option[T] =
  if v == "": T.none else: T.parse(v).some