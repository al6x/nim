import tables, sugar, optionm, supportm

export tables

# map ----------------------------------------------------------------------------------------------
proc map*[K, V, R](table: Table[K, V] | ref Table[K, V], convert: proc (v: V, k: K): R): Table[K, R] =
  for k, v in table: result[k] = convert(v, k)

proc map*[K, V, R](table: Table[K, V] | ref Table[K, V], convert: proc (v: V): R): Table[K, R] =
  for k, v in table: result[k] = convert(v)


# filter -------------------------------------------------------------------------------------------
proc filter*[K, V](table: Table[K, V], predicate: proc (v: V): bool): Table[K, V] =
  for k, v in table:
    if predicate(v): result[k] = v

proc filter*[K, V](table: Table[K, V], predicate: proc (v: V, k: K): bool): Table[K, V] =
  for k, v in table:
    if predicate(v, k): result[k] = v

proc filter*[K, V](table: Table[K, Option[V]] | ref Table[K, Option[V]]): Table[K, V] =
  for k, o in table:
    if o.is_some: result[k] = o.get


# filter_map ---------------------------------------------------------------------------------------
proc filter_map*[K, V, R](table: Table[K, V] | ref Table[K, V], convert: proc (v: V): Option[R]): Table[K, R] =
  for k, v in table:
    let o = convert(v)
    if o.is_some: result[k] = o.get

test "filter_map":
  assert { "a": -1.0, "b": 2.0 }.to_table.filter_map(proc (v: float): auto =
    if v > 0: ($v).some else: string.none
  ) == { "b": "2.0" }.to_table


# keys ---------------------------------------------------------------------------------------------
proc keys*[K, V](table: Table[K, V]): seq[K] =
  for k in table.keys: result.add k


# values -------------------------------------------------------------------------------------------
proc values*[K, V](table: Table[K, V] | ref Table[K, V]): seq[V] =
  for v in table.values: result.add v


# to_table -----------------------------------------------------------------------------------------
proc to_table*[V, K](list: openarray[V], key: (V) -> K): Table[K, V] =
  for v in list: result[key(v)] = v

proc to_table*[V, K](list: openarray[V], key: (V, int) -> K): Table[K, V] =
  for i, v in list: result[key(v, i)] = v


# ensure -------------------------------------------------------------------------------------------
proc ensure*[K, V](table: Table[K, V], key: K, message = "key not found"): V =
  if key notin table: throw(message)
  table[key]


# get_optional -------------------------------------------------------------------------------------
proc get_optional*[K, V](table: Table[K, V] | ref Table[K, V], key: K, message = "key not found"): Option[V] =
  if key notin table: V.none(message)
  else:               table[key].some