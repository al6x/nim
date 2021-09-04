require std/[times, hashes, random, strutils]
require ./[support, env, table]

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


# sample -------------------------------------------------------------------------------------------
proc sample*[V](list: openarray[V], rgen: var Rand): V =
  rgen.sample(list)

proc sample*[V](list: openarray[V], count: int, rgen: var Rand): seq[V] =
  for _ in 1..count:
    result.add list.sample(rgen)


# secure_random_token ------------------------------------------------------------------------------
let az = "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z"
let azAz09 = (az & " " & az.to_lower & " 0 1 2 3 4 5 6 7 8 9").split(" ")

proc secure_random_token*(n = 30): string =
  var rgen = secure_rgen()
  # $secure_hash(rgen.rand(int.high).to_s)
  azAz09.sample(n, rgen).join("")


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  echo secure_random_token()
