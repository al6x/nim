import ./supportm, sugar

# is_empty -----------------------------------------------------------------------------------------
proc is_empty*(o: tuple): bool =
  for _, _ in o.field_pairs: return false
  return true

# map ----------------------------------------------------------------------------------------------
func map*[V, R](t: (V, ), op: (v: V) -> R): (R, ) =
  (op(t[0]), )

func map*[V, R](t: (V, V), op: (v: V) -> R): (R, R) =
  (op(t[0]), op(t[1]))

func map*[V, R](t: (V, V, V), op: (v: V) -> R): (R, R, R) =
  (op(t[0]), op(t[1]), op(t[2]))


# func map*[V, R](t: (V, V, V, V), op: (v: V) -> R): (R, R, R, R) =
#   (op(t[0]), op(t[1]), op(t[2]), op(t[3]))

# func map*[V, R](t: (V, V, V, V, V), op: (v: V) -> R): (R, R, R, R, R) =
#   (op(t[0]), op(t[1]), op(t[2]), op(t[3]), op(t[4]))

# # first --------------------------------------------------------------------------------------------
# func first*[V](v: (V,)): V = v[0]
# func first*[V, B](v: (V, B)): V = v[0]
# func first*[V, B, C](v: (V, B, C)): V = v[0]
# func first*[V, B, C, D](v: (V, B, C, D)): V = v[0]

# # first --------------------------------------------------------------------------------------------
# func second*[V, B](v: (V, B)): B = v[1]
# func second*[V, B, C](v: (V, B, C)): B = v[1]
# func second*[V, B, C, D](v: (V, B, C, D)): B = v[1]

# # third --------------------------------------------------------------------------------------------
# func third*[V, B, C](v: (V, B, C)): C = v[2]
# func third*[V, B, C, D](v: (V, B, C, D)): C = v[2]

# # last ---------------------------------------------------------------------------------------------
# func last*[V, B](v: (V, B)): B = v[1]
# func last*[V, B, C](v: (V, B, C)): C = v[2]
# func last*[V, B, C, D](v: (V, B, C, D)): D = v[3]
