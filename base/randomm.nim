import ./supportm, ./envm, ./tablem
import std/sha1, times, hashes, random

export Rand

# secure_rgen --------------------------------------------------------------------------------------
let seed1: int64 = block:
  let now = get_time()
  var rgen = init_rand(now.to_unix * 1_000_000_000 + now.nanosecond)
  @[rgen.rand(int.high), env.values.hash.int].hash.int64

proc secure_rgen*(): Rand =
  let now = get_time()
  let seed2 = now.to_unix * 1_000_000_000 + now.nanosecond
  init_rand(@[seed1, seed2].hash)


# secure_random_token ------------------------------------------------------------------------------
proc secure_random_token*(): string =
  var rgen = secure_rgen()
  $secure_hash(rgen.rand(int.high).to_s)


# sample -------------------------------------------------------------------------------------------
proc sample*[V](list: openarray[V], rgen: var Rand): V =
  rgen.sample(list)

proc sample*[V](list: openarray[V], count: int, rgen: var Rand): seq[V] =
  for _ in 1..count:
    result.add list.sample(rgen)