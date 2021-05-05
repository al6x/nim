import nodem, os, ./redisi

let redis = redis_node"redis"

while true:
  try:
    redis.publish("updates", "some news")
  except:
    discard
  sleep 1000