import base

type Config* = ref object
  version*:               int
  home*:                  Option[string] # id of home page


  allowed_tags*:          HashSet[string]
  text_around_match_len*: Option[int] # len of text around match