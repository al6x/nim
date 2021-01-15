import supportm, stringm


# parse_yes_no ---------------------------------------------------------------------------
proc parse_boolean*(raw: string, default: bool): bool =
  case raw.to_lower
  of "":    default
  of "yes", "true":  true
  of "no",  "false": false
  else:     throw fmt"invalid yes/true/no/false '{raw}'"