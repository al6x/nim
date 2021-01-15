import json

export json

# T.to_json ----------------------------------------------------------------------------------------
proc to_json*[T](v: T, pretty = true): string =
  if pretty: (%v).pretty else: $(%v)


# T.from_json ----------------------------------------------------------------------------------------
# proc from_json*[T](v: type[T], json: string): T = json.parse_json.to(T)