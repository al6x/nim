require std/[tables, sugar, hashes]
require ./[option, support]

export tablesm

# map ----------------------------------------------------------------------------------------------
proc map*[K, V, R](table: Table[K, V] | ref Table[K, V], convert: (V, K) -> R): Table[K, R] =
  for k, v in table: result[k] = convert(v, k)

proc map*[K, V, R](table: Table[K, V] | ref Table[K, V], convert: (V) -> R): Table[K, R] =
  for k, v in table: result[k] = convert(v)


# filter -------------------------------------------------------------------------------------------
proc filter*[K, V](table: Table[K, V] | ref Table[K, V], predicate: (V) -> bool): Table[K, V] =
  for k, v in table:
    if predicate(v): result[k] = v

proc filter*[K, V](table: Table[K, V] | ref Table[K, V], predicate: (V, K) -> bool): Table[K, V] =
  for k, v in table:
    if predicate(v, k): result[k] = v

proc filter*[K, V](table: Table[K, Option[V]] | ref Table[K, Option[V]]): Table[K, V] =
  for k, o in table:
    if o.is_some: result[k] = o.get


# filter_map ---------------------------------------------------------------------------------------
proc filter_map*[K, V, R](table: Table[K, V] | ref Table[K, V], convert: (V) -> Option[R]): Table[K, R] =
  for k, v in table:
    let o = convert(v)
    if o.is_some: result[k] = o.get

test "filter_map":
  assert { "a": -1.0, "b": 2.0 }.to_table.filter_map(proc (v: float): auto =
    if v > 0: ($v).some else: string.none
  ) == { "b": "2.0" }.to_table


# keys ---------------------------------------------------------------------------------------------
proc keys*[K, V](table: Table[K, V] | ref Table[K, V]): seq[K] =
  for k in table.keys: result.add k


# values -------------------------------------------------------------------------------------------
proc values*[K, V](table: Table[K, V] | ref Table[K, V]): seq[V] =
  for v in table.values: result.add v

proc values*[K, V](table: OrderedTable[K, V] | ref OrderedTable[K, V]): seq[V] =
  for v in table.values: result.add v


# to_table -----------------------------------------------------------------------------------------
proc to_table*[V, K](list: openarray[V], key: (V) -> K): Table[K, V] =
  for v in list: result[key(v)] = v

proc to_table*[V, K](list: openarray[V], key: (V, int) -> K): Table[K, V] =
  for i, v in list: result[key(v, i)] = v


# to_index -----------------------------------------------------------------------------------------
proc to_index*[V](list: openarray[V]): Table[V, int] =
  for i, v in list: result[v] = i


# ensure -------------------------------------------------------------------------------------------
proc ensure*[K, V](table: Table[K, V], key: K, message = "key not found"): V {.inline.} =
  if key notin table: throw(message)
  table[key]


# get_optional -------------------------------------------------------------------------------------
proc get_optional*[K, V](table: Table[K, V] | ref Table[K, V], key: K): Option[V] {.inline.} =
  if key notin table: V.none else: table[key].some


# get ----------------------------------------------------------------------------------------------
proc get*[K, V](table: Table[K, V] | ref Table[K, V], key: K, default: V): V {.inline.} =
  table.get_or_default(key, default)

proc get*[K, V](table: Table[K, V] | ref Table[K, V], key: K, default: () -> V): V {.inline.} =
  if key notin table: default() else: table[key]


# [key, default] -----------------------------------------------------------------------------------
proc `[]`*[K, V](table: Table[K, V] | ref Table[K, V], key: K, default: V): V {.inline.} =
  table.get_or_default(key, default)

proc `[]`*[K, V](table: Table[K, V] | ref Table[K, V], key: K, default: () -> V): V {.inline.} =
  if key notin table: default() else: table[key]


# mget ---------------------------------------------------------------------------------------------
proc mget*[K, V](table: var Table[K, V], key: K, value: V): V =
  table.mget_or_put(key, value)
proc mget*[K, V](table: var ref Table[K, V], key: K, value: V): V =
  table.mget_or_put(key, value)

proc mget*[K, V](table: var Table[K, V], key: K, value: (() -> V)): V =
  if key notin table: table.mget_or_put(key, value()) else: table[key]
proc mget*[K, V](table: var ref Table[K, V], key: K, value: (() -> V)): V =
  if key notin table: table.mget_or_put(key, value()) else: table[key]


# & ------------------------------------------------------------------------------------------------
# Merge two tables, same keys in the first table will be overwritten
proc `&`*[K, V](a, b: Table[K, V] | ref Table[K, V]): Table[K, V] =
  for k, v in a: result[k] = v
  for k, v in b: result[k] = v


# inc ----------------------------------------------------------------------------------------------
proc inc*[K](table: var Table[K, int], key: K, v: int = 1): void {.inline.} =
  table[key] = table.get_or_default(key, 0) + v

test "inc":
  var counts: Table[string, int]
  counts.inc("a")
  counts.inc("a", 2)
  assert counts["a"] == 3


# update -------------------------------------------------------------------------------------------
proc update*[K, V](
  table: var Table[K, V] | ref Table[K, V], key: K, op: ((V) -> V), default: V
): void {.inline.} =
  table[key] = op(table.get_or_default(key, default))


# hash ---------------------------------------------------------------------------------------------
proc hash*[K, V](table: Table[K, V] | ref Table[K, V]): Hash =
  for k, v in table:
    result = result !& k.hash !& v.hash
  result = !$result