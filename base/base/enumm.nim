import std/[macros, strutils]

macro autoconvert*(TT: type[enum]) =
  let fname = ident "to_" & $(TT)
  quote do:
    converter `fname`*(s: string): `TT` = parse_enum[`TT`](s)