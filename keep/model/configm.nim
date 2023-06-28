import base

type Config* = ref object
  version*:               int
  home*:                  Option[string] # id of home page

  allowed_tags*:          HashSet[string]
  text_around_match_len*: int # len of text around match
  per_page*:              int

proc init*(_: type[Config]): Config =
  Config(
    text_around_match_len: 80,
    per_page:              30
  )