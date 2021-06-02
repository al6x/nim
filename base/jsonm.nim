import json except to, `%`
import std/jsonutils

export json, jsonutils

proc to_s*(json: JsonNode, pretty = true): string =
  if pretty: pretty(json) else: $json

proc json_to*(json: JsonNode, T: typedesc, options: Joptions): T =
  from_json(result, json, options)


# update_from --------------------------------------------------------------------------------------
proc update_from*[T](o: var T, partial: JsonNode): void =
  for k, v in o.field_pairs:
    if k in partial.fields:
      v = partial.fields[k].json_to(typeof v)


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

proc to_json_hook*[T: tuple](o: T): JsonNode =
  result = new_JObject()
  for k, v in o.field_pairs: result[k] = v.to_json


# T.from_json ----------------------------------------------------------------------------------------
# proc from_json*[T](_: type[T], json: string): T = json.parse_json.to(T)