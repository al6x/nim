import sugar, jsonm, optionm, timem
from fs import nil


proc read_from_optional*[T](t: type[T], path: string): Option[T] =
  try:
    let json = fs.read path
    json.parse_json.to_json(T).some
  except:
    T.none

proc read_from*[T](t: type[T], path: string): T =
  let v = read_from_optional(t, path)
  if v.is_some: v.get else: T.init

proc read_from*[T](t: type[T], path: string, default: () -> T): T =
  let v = read_from_optional(t, path)
  if v.is_some: v.get else: default()


proc write_to*[T](v: T, path: string): void =
  fs.write(path, $(v.to_json))


# cache --------------------------------------------------------------------------------------------
type Cache[T] = object
  value:     T
  timestamp: Time
  version:   int

let cache_version = 1

proc cache*[T](path: string, expiration_sec: int, build: () -> T): T =
  proc build_and_write(): Cache[T] =
    let v = build()
    let cache = Cache(value: v, timestamp: Time.now(), version: cache_version)
    cache.write_to(path)
    cache
  var cached = Cache[T].read_from_optional(path, build_and_write)
  if (cached.version != cache_version) or ((Time.now.epoch - cached.timestamp.epoch) > expiration_sec):
    cached = build_and_write()
  cached.value