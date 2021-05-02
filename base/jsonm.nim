import json

export json


# T.to_json ----------------------------------------------------------------------------------------
proc to_json*[T](v: T, pretty = true): string =
  if pretty: (%v).pretty else: $(%v)


proc `%`*[T: tuple](o: T): JsonNode =
  result = new_JObject()
  for k, v in o.field_pairs: result[k] = %v


# T.from_json ----------------------------------------------------------------------------------------
# proc from_json*[T](_: type[T], json: string): T = json.parse_json.to(T)