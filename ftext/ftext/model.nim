import base

# template import_keep =
#   import keep/model/docm

# when compiles(import_keep()):
#   import keep/model/docm
#   export docm
# else:
#   import ./model/fdoc
#   export fdoc

import keep/model/[docm, helpers]
export docm, helpers

type
  FBlockSource* = ref object of BlockSource
    text*, id*, args*: string
    line_n*: (int, int) # block position in text
    tags*: seq[string]

  FDocSource* = ref object of DocSource
    tags_line_n*: (int, int) # tags position in text
    tags*: seq[string]