import envm, tablem, random
import std/sha1, times, hashes

# secure_random ------------------------------------------------------------------------------------
let seed1: int = block:
  let now = get_time()
  var rgen = init_rand(now.to_unix * 1_000_000_000 + now.nanosecond)
  @[rgen.rand(int.high), env.hash.int].hash.int

proc secure_random*(): string {.gcsafe.} =
  let seed2 = block:
    let now = get_time()
    var rgen = init_rand(now.to_unix * 1_000_000_000 + now.nanosecond)
    rgen.rand(int.high)

  let seed = @[seed1, seed2].hash.int
  $secure_hash($seed)