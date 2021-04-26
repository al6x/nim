import nodem, ./redisi, options

let redis = redis_node"redis"

redis.publish("updates", "some news")