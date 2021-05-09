import json except to, `%`
import std/jsonutils

export json, jsonutils

proc jsonTo*(json: JsonNode, T: typedesc, options: Joptions): T =
  fromJson(result, json, options)

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