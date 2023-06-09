import base, ext/vcache, ./docm, ./configm

type
  Space* = ref object
    id*:           string
    version*:      int
    docs*:         Table[string, Doc]
    ntags*:        seq[string] # lowercased
    tags*:         seq[string]
    warnings*:     seq[string]
    # processors*:   seq[proc()]
    allowed_tags*: HashSet[string]
    # cache*:        Table[string, JsonNode]

  Db* = ref object
    version*:     int
    config*:      Config
    spaces*:      Table[string, Space]
    cache*:       VCache
    # space_cache*: Table[(string, string), VCacheContainer]
    bgjobs*:      seq[proc()]

proc log*(self: Space): Log =
  Log.init("Space", self.id)

proc init*(_: type[Space], id: string, version = 0): Space =
  Space(id: id, version: version)

iterator blocks*(space: Space): Block =
  for _, doc in space.docs:
    for blk in doc.blocks:
      yield blk

iterator blocks*(db: Db): Block =
  for _, space in db.spaces:
    for _, doc in space.docs:
      for blk in doc.blocks:
        yield blk

proc validate_tags*(space: Space) =
  if not space.allowed_tags.is_empty:
    for blk in space.blocks:
      for tag in blk.tags:
        if tag notin space.allowed_tags:
          blk.warns.add fmt"Invalid tag: {tag}"

proc validate_links*(space: Space, db: Db) =
  for blk in space.blocks:
    for link in blk.links:
      let (sid, did, bid) = link
      try:
        let doc = (if sid == ".": space else: db.spaces[sid]).docs[did]
        unless bid.is_empty: discard doc.blockids[bid]
      except:
        blk.warns.add fmt"Invalid link: {link.to_s}"

proc ntags*(db: Db): Table[string, int] =
  for blk in db.blocks:
    for ntag in blk.ntags:
      result.inc ntag

proc ntags_cached*(db: Db): Table[string, int] =
  db.cache.get_into("ntags", db.version, result, db.ntags)