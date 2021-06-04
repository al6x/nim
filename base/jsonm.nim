import json except to, `%`, `%*`
import std/jsonutils

export json except to, `%`, `%*`, pretty, toUgly
export jsonutils except json_to, from_json, Joptions


proc to_s*(json: JsonNode, pretty = true): string =
  if pretty: pretty(json) else: $json


proc json_to*(json: JsonNode, T: typedesc): T =
  from_json(result, json, Joptions(allow_extra_keys: true))


proc to_json_hook*[T: tuple](o: T): JsonNode =
  result = new_JObject()
  for k, v in o.field_pairs: result[k] = v.to_json


proc update_from*[T](o: var T, partial: JsonNode): void =
  for k, v in o.field_pairs:
    if k in partial.fields:
      v = partial.fields[k].json_to(typeof v)



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