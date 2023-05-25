import base

template cached_with_result*(cache: Table[string, JsonNode], key: string, version: int, code): auto =
  unless key in cache and cache[key]["version"].get_int == version:
    let result = code
    let jo = newJObject(); jo["version"] = % version; jo["result"]  = % result
    cache[key] = jo
  cache[key]["result"].json_to(typeof(code))

template cached*(cache: Table[string, JsonNode], key: string, version: int, code): auto =
  when compiles(cached_with_result(cache, key, version, code)):
    cached_with_result(cache, key, version, code)
  else:
    discard cached_with_result(cache, key, version):
      code
      true