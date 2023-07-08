import base

type
  RecordId* = tuple[sid, rid: string]

  RecordSource* = ref object of RootObj
    tags*: seq[string]

  Record* = ref object of RootObj
    kind*:    string
    id*:      string
    text*:    string
    hash*:    int
    tags*:    seq[string]
    links*:   seq[RecordId]
    warns*:   seq[string]
    updated*: Epoch
    sid*:     string
    source*:  RecordSource

  Container* = ref object of Record

  Space* = ref object
    id*:           string
    version*:      int
    records*:      Table[string, Record]
    # containers*:   Table[int, Container]
    tags*:         seq[string]
    warns*:        seq[string]

proc `$`*(rid: RecordId): string =
  "/" & rid.sid & "/" & rid.rid # & (if link.bid.is_empty: "" else: "/" & link.bid)

# Space --------------------------------------------------------------------------------------------
proc init*(_: type[Space], id: string, version = 0): Space =
  Space(id: id, version: version)

proc log*(self: Space): Log =
  Log.init("Space", self.id)

proc `[]`*(space: Space, id: string): Record =
  space.records[id]

proc get*(space: Space, id: string): Option[Record] =
  if id in space.records: return space.records[id].some

proc contains*(space: Space, id: string): bool =
  id in space.records

iterator items*(space: Space): Record =
  for _, record in space.records: yield record