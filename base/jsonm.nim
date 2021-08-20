import std/json except to, `%`, `%*`
import std/macros, std/options
import ./std_jsonutils

export json except to, `%`, `%*`, pretty, toUgly
export std_jsonutils except json_to, from_json, Joptions


template json_as_string*[T](_: type[T]): void =
  func to_json_hook*(v: T): JsonNode = v.to_s.to_json
  proc from_json_hook*(v: var T, json: JsonNode) = v = T.init(json.get_str)


proc to_s*(json: JsonNode, pretty = true): string =
  if pretty: pretty(json) else: $json


proc json_to*(json: JsonNode, T: typedesc): T =
  from_json(result, json, Joptions(allow_extra_keys: true))


# proc to_json_hook*[T: tuple](o: T): JsonNode =
#   result = new_JObject()
#   for k, v in o.field_pairs: result[k] = v.to_json

proc to_json_hook*(list: openarray[(string, JsonNode)]): JsonNode =
  # Needed for `%` to work properly
  result = newJObject()
  for item in list: result[item[0]] = item[1]

# proc to_json_hook*(n: JsonNode): JsonNode =
#   n

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

when is_main_module:
  let b = "some"
  echo %{ a: 1, b: "b" }

  type Unit = object
    name: string
  echo Unit.jinit { name: "Jim" }

  # Ignoring nil and empty options
  assert (a: 1.some, b: int.none, c: nil).to_json.to_s(pretty = false) == """{"a":1}"""

  # Encoding enums as stings
  type SomeEnum* = enum some_name
  assert SomeEnum.some_name.to_json.to_s == "\"some_name\""
  assert parse_json("\"some_name\"").json_to(SomeEnum) == SomeEnum.some_name



# Patching jsonutils https://github.com/nim-lang/Nim/issues/18151
#
# template fromJsonFields(newObj, oldObj, json, discKeys, opt) =
#   type T = typeof(newObj)
#   # we could customize whether to allow JNull
#   checkJson json.kind == JObject, $json.kind
#   var num, numMatched = 0
#   for key, val in fieldPairs(newObj):
#     num.inc
#     when key notin discKeys:
#       if json.hasKey key:
#         numMatched.inc
#         fromJson(val, json[key])
# # Change begin --------------------
# # Allowing field Option[T] to be missing
#       elif val is Option:
#         num.dec
#         fromJson(val, newJNull())
# # Change end ----------------------
#       elif opt.allowMissingKeys:
#         # if there are no discriminant keys the `oldObj` must always have the
#         # same keys as the new one. Otherwise we must check, because they could
#         # be set to different branches.
#         when typeof(oldObj) isnot typeof(nil):
#           if discKeys.len == 0 or hasField(oldObj, key):
#             val = accessField(oldObj, key)
#       else:
#         checkJson false, $($T, key, json)
#     else:
#       if json.hasKey key:
#         numMatched.inc
#   let ok =
# # Change begin --------------------
# # Always allowing extra keys as option passing is broken in jsonutils
#     # if opt.allowExtraKeys and opt.allowMissingKeys:
#     if true and opt.allowMissingKeys:
#       true
#     # elif opt.allowExtraKeys:
#     elif true:
# # Change begin --------------------
#       # This check is redundant because if here missing keys are not allowed,
#       # and if `num != numMatched` it will fail in the loop above but it is left
#       # for clarity.
#       assert num == numMatched
#       num == numMatched
#     elif opt.allowMissingKeys:
#       json.len == numMatched
#     else:
#       json.len == num and num == numMatched

#   checkJson ok, $(json.len, num, numMatched, $T, json)





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