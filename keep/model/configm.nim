import base

type Config* = ref object
  version*:      int
  allowed_tags*: HashSet[string]
  home*:         Option[string] # id of home page