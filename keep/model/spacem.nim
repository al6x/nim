import base, ext/vcache, ./docm, ./configm, ./trigrams

type
  Space* = ref object
    id*:           string
    version*:      int
    docs*:         Table[string, Doc]
    tags*:         seq[string]
    warnings*:     seq[string]
    # processors*:   seq[proc()
    # cache*:        Table[string, JsonNode]

    ntags*:        seq[string] # lowercased

proc log*(self: Space): Log =
  Log.init("Space", self.id)

proc init*(_: type[Space], id: string, version = 0): Space =
  Space(id: id, version: version)

iterator blocks*(space: Space): Block =
  for _, doc in space.docs:
    for blk in doc.blocks:
      yield blk

proc post_process*(space: Space, doc: Doc) =
  block: # Merging and normalising tags
    let doc_ntags = (doc.tags.map(to_lower) & space.ntags).sort
    for blk in doc.blocks:
      let block_ntags = blk.tags.map(to_lower)
      blk.ntags = (block_ntags & doc_ntags).unique.sort
      doc.ntags.add block_ntags
    doc.ntags = doc.ntags.unique.sort

  block: # Trigrams
    for blk in doc.blocks:
      blk.text.to_lower.to_trigrams doc.trigrams
      for tag in blk.ntags: tag.to_trigrams blk.trigrams
      blk.trigrams_us = blk.trigrams.unique.sort
      doc.trigrams_us.add blk.trigrams_us
    doc.trigrams_us = doc.trigrams.unique.sort

iterator docs*(space: Space): Doc =
  for _, doc in space.docs: yield doc

proc `[]`*(space: Space, doc_id: string): Doc =
  space.docs[doc_id]

proc contains*(space: Space, doc_id: string): bool =
  doc_id in space.docs

proc apdate*(space: Space, doc: Doc) =
  space.post_process doc
  space.docs[doc.id] = doc

proc del*(space: Space, doc_id: string) =
  space.docs.del doc_id
