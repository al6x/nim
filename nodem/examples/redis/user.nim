import nodem, ./redisi, options, strformat

let redis = redis_node"redis"
let user  = node"user1"

# # Counters ------------------------------------------------
# redis.inc_counter "http://sales.com"
# echo redis.get_counter "http://sales.com"

# # K/V store -----------------------------------------------
redis.set("sessions/1", "session data")
echo redis.get("sessions/1").get

# Pub/Sub -------------------------------------------------
redis.subscribe(user, "updates")

proc notify*(_: Node, topic: string, message: string): void {.nexport.} =
  echo fmt"new message {topic}: {message}"

spawn_async user.run
echo "user started"
run_forever()

# # # user.define "tcp://localhost:4000" # optional, will be auto-set
