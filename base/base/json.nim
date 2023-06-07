import std/json except to, `%`, `%*`
import std/[macros, options, tables, algorithm]
import ./std_jsonutils

import ./option, ./seqm, ./check

export json except to, `%`, `%*`, pretty, toUgly
export std_jsonutils except json_to, from_json, Joptions


template json_as_string*[T](_: type[T]): void =
  func to_json_hook*(v: T): JsonNode = v.to_s.to_json
  proc from_json_hook*(v: var T, json: JsonNode) = v = T.init(json.get_str)


proc to_s*(json: JsonNode, pretty = true): string =
  if pretty: pretty(json) else: $json


proc json_to*[T](json: JsonNode, v: var T) =
  from_json(v, json, Joptions(allow_extra_keys: true))

proc json_to*(json: JsonNode, T: typedesc): T =
  from_json(result, json, Joptions(allow_extra_keys: true))

proc to_json_hook*(list: openarray[(string, JsonNode)]): JsonNode =
  # Needed for `%` to work properly
  result = newJObject()
  for item in list: result[item[0]] = item[1]

proc toJoImpl(x: NimNode): NimNode {.compileTime.} =
  # Same as `%*` but:
  # - allows not to quote object keys
  # - uses jsonutils.to_json instead of json.%
  case x.kind
  of nnkBracket: # array
    if x.len == 0: return newCall(bindSym"newJArray")
    result = newNimNode(nnkBracket)
    for i in 0 ..< x.len:
      result.add(toJoImpl(x[i]))
    result = newCall(bindSym("to_json", brOpen), result)
  of nnkTableConstr: # object
    if x.len == 0: return newCall(bindSym"newJObject")
    result = newNimNode(nnkTableConstr)
    for i in 0 ..< x.len:
      x[i].expectKind nnkExprColonExpr
      let key = if x[i][0].kind == nnkIdent: newStrLitNode(x[i][0].str_val) else: x[i][0]
      result.add newTree(nnkExprColonExpr, key, toJoImpl(x[i][1]))
    result = newCall(bindSym("to_json", brOpen), result)
  of nnkCurly: # empty object
    x.expectLen(0)
    result = newCall(bindSym"newJObject")
  of nnkNilLit:
    result = newCall(bindSym"newJNull")
  of nnkPar:
    if x.len == 1: result = toJoImpl(x[0])
    else: result = newCall(bindSym("to_json", brOpen), x)
  else:
    result = newCall(bindSym("to_json", brOpen), x)

macro `%`*(v: untyped): JsonNode =
  # Convert an expression to a JsonNode directly, without having to specify to_json for every element.
  toJoImpl(v)

macro jinit*[T](TT: type[T], x: untyped): T =
  let jobject = toJoImpl(x)
  quote do:
    `jobject`.json_to(`TT`)


proc update_from*[T](o: var T, partial: JsonNode): void =
  for k, v in o.field_pairs:
    if k in partial.fields:
      v = partial.fields[k].json_to(typeof v)


proc to_columns*[T](tidydata: seq[T]): JsonNode =
  # Converts tidydata to columnar format to consume less space
  let records: seq[JsonNode] = tidydata.to_json.elems

  var keys: seq[string]
  for r in records:
    for k in r.keys: keys.add k
  keys = keys.unique

  var columns = new_JObject()
  for k in keys: columns[k] = new_JArray()

  for r in records:
    for k in keys:
      columns[k].add(if k in r: r[k] else: new_JNull())
  columns

proc sort*(node: JsonNode): JsonNode =
  # Nim JSON is different depends on inserting order, sorting to make it the same.
  var copy: JsonNode
  if node.kind == JObject:
    copy = new_JObject()
    for k, v in node.fields:
      copy[k] = v.sort
    copy.fields.sort(cmp)
  elif node.kind == JArray:
    copy = new_JArray()
    for v in node:
      copy.add v.sort
  else:
    copy = node.copy
  copy


# Test ----------------------------------------------------------------------------------------------
when is_main_module:
  # % helper
  let b = "some"
  check (%{ a: 1, b: "b" }).to_s(false) == """{"a":1,"b":"b"}"""

  let attrs = %{ title: "Some page" }
  check ($(attrs)).parse_json == attrs

  # JsonNode.to_json
  let char_range: 'a'..'z' = 'a'
  check (v: char_range).to_json.to_s(false) == """{"v":"a"}"""

  # JsonNode.to_json
  check (a: 1).to_json.to_json.to_s(false) == """{"a":1}"""

  # jinit
  type Unit = object
    name: string
  check (Unit.jinit { name: "Jim" }) == Unit(name: "Jim")

  # Ignoring nil and empty options
  check (a: 1.some, b: int.none, c: nil).to_json.to_s(pretty = false) == """{"a":1}"""

  # Encoding enums as stings
  type SomeEnum* = enum some_name
  check SomeEnum.some_name.to_json.to_s == "\"some_name\""
  check parse_json("\"some_name\"").json_to(SomeEnum) == SomeEnum.some_name

  block: # json_to should support two ways
    var v: int
    1.to_json.json_to(v)
    check v == 1
    check 1.to_json.json_to(int) == 1

  # From bugs
  check @[(a: 1.0.some)].to_json.to_s(false) == """[{"a":1.0}]"""

  # Stable, with sorted object keys
  check (%{ a: 1, b: 2 }).sort.to_s(false) == (%{ b: 2, a: 1 }).sort.to_s(false)


# when is_main_module: # Any
#   var any = Any.init
#   any["a"] = "some"
#   any["b"] = 1
#   echo any.to_s




# proc is_same_values[T](o: T, partial: JsonNode): bool =
#   for k, v in o.field_pairs:
#     if k in partial.fields:
#       if v != partial.fields[k].json_to(typeof v): return false
#   true


# T.to_json ----------------------------------------------------------------------------------------
# proc to_json*[T](v: T, pretty = true): string =
#   if pretty: (%v).pretty else: $(%v)

# proc `%`*[T: tuple](o: T): JsonNode =
#   result = new_JObject()
#   for k, v in o.field_pairs: result[k] = %v

# T.from_json ----------------------------------------------------------------------------------------
# proc from_json*[T](_: type[T], json: string): T = json.parse_json.to(T)


# proc to_json_hook*[T: tuple](o: T): JsonNode =
#   result = new_JObject()
#   for k, v in o.field_pairs: result[k] = v.to_json

# proc to_json_hook*(n: JsonNode): JsonNode =
#   n

# type Any* = JsonNode

# proc init*(_: type[Any]): Any =
#   newJObject()

# proc `[]=`*[T](obj: JsonNode, key: string, val: T) =
#   obj[key] = when T is JsonNode: val else: val.to_json
