import base

type
  VCacheContainer* = tuple[version: JsonNode, life_ms: TimerMs, value: JsonNode]
  VCache* = Table[string, VCacheContainer]

template get*[V, T](cache: var VCache, key: string, version: V, life_ms: int, TT: type[T], code): T =
  unless key in cache and (cache[key][0] == version.to_json or cache[key][1]() <= life_ms):
    var v: T = code
    cache[key] = (version.to_json, timer_ms(), v.to_json)
  cache[key].value.json_to(TT)

template get*[V, T](cache: var VCache, key: string, version: V, TT: type[T], code): T =
  get(cache, key, version, -1, TT, code)

template get_into*[V, T](cache: var VCache, key: string, version: V, result: T, code) =
  result = get(cache, key, version, -1, typeof result, code)

template process*(cache: var VCache, key: string, version: int, life_ms: int, code) =
  unless key in cache and (cache[key][0] == version.to_json or cache[key][1]() <= life_ms):
    code
    cache[key] = (version.to_json, timer_ms(), %{})

template process*[K](cache: var VCache, key: K, version: int, code) =
  process(cache, key, version, -1, code)

test "get":
  var cache = VCache()
  check cache.get("k1", 1, string, "v1") == "v1"

  var v1: string
  cache.get_into("k1", 1, v1, "v1")
  check v1 == "v1"