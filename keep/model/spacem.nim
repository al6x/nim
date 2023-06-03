import base, ext/vcache, ./docm

type
  Space* = ref object
    id*:           string
    version*:      int
    docs*:         Table[string, Doc]
    warnings*:     seq[string]
    processors*:   seq[proc()]
    bgjobs*:       seq[proc()]
    allowed_tags*: HashSet[string]
    cache*:        Table[string, JsonNode]

  Db* = ref object
    spaces*: Table[string, Space]
    cache*:  Table[string, JsonNode]

proc log*(self: Space): Log =
  Log.init("Space", self.id)

proc init*(_: type[Space], id: string, version = 0): Space =
  Space(id: id, version: version)

proc local_link_to_s*(link: (string, string)): string =
  if link[0] == ".": link[1] else: link[0] & "/" & link[1]

iterator blocks*(space: Space): Block =
  for _, doc in space.docs:
    for blk in doc.blocks:
      yield blk

proc validate_tags*(space: Space) =
  if not space.allowed_tags.is_empty:
    for blk in space.blocks:
      for tag in blk.tags:
        if tag notin space.allowed_tags:
          blk.warns.add fmt"Invalid tag: {tag}"

proc validate_links*[Db](space: Space, db: Db) =
  for blk in space.blocks:
    for link in blk.links:
      let (sid, did) = link
      if sid == ".":
        if did notin space.docs:
          blk.warns.add fmt"Invalid link: {link.local_link_to_s}"
      else:
        if sid notin db.spaces:
          blk.warns.add fmt"Invalid link: {link.local_link_to_s}"
        else:
          if did notin space.docs:
            blk.warns.add fmt"Invalid link: {link.local_link_to_s}"