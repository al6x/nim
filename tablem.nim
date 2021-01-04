import tables, sugar, optionm

export tables

# map ----------------------------------------------------------------------------------------------
proc map*[K, V, R](table: Table[K, V], convert: proc (v: V, k: K): R): Table[K, R] =
  for k, v in table: result[k] = convert(v, k)

proc map*[K, V, R](table: Table[K, V], convert: proc (v: V): R): Table[K, R] =
  for k, v in table: result[k] = convert(v)


# filter -------------------------------------------------------------------------------------------
proc filter*[K, V](table: Table[K, V], predicate: proc (v: V): bool): Table[K, V] =
  for k, v in table:
    if predicate(v): result[k] = v

proc filter*[K, V](table: Table[K, V], predicate: proc (v: V, k: K): bool): Table[K, V] =
  for k, v in table:
    if predicate(v, k): result[k] = v


# filter_map ---------------------------------------------------------------------------------------
proc filter_map*[K, V, R](table: Table[K, V], convert: proc (v: V): Option[R]): Table[K, R] =
  for k, v in table:
    let o = convert(v)
    if o.is_some: result[k] = o.get


# keys ---------------------------------------------------------------------------------------------
proc keys*[K, V](table: Table[K, V]): seq[K] =
  for k in table.keys: result.add k


# to_table -----------------------------------------------------------------------------------------
proc to_table*[V, K](list: openarray[V], key: (V) -> K): Table[K, V] =
  for v in list: result[key(v)] = v

proc to_table*[V, K](list: openarray[V], key: (V, int) -> K): Table[K, V] =
  for i, v in list: result[key(v, i)] = v