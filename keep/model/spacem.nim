import base, ext/[vcache, grams], ./docm, ./configm

proc log*(self: Space): Log =
  Log.init("Space", self.id)

proc init*(_: type[Space], id: string, version = 0): Space =
  Space(id: id, version: version)

iterator blocks*(space: Space): Block =
  for _, doc in space.docs:
    for blk in doc.blocks:
      yield blk

proc post_process*(space: Space, doc: Doc) =
  block: # Refs
    doc.space = space
    for blk in doc.blocks: blk.doc = doc

  block: # Merging and normalising tags
    let doc_ntags = (doc.tags.map(encode_tag) & space.ntags).sort
    for blk in doc.blocks:
      let block_ntags = blk.tags.map(encode_tag)
      blk.ntags = (block_ntags & doc_ntags).unique.sort
      doc.ntags.add block_ntags
    doc.ntags = doc.ntags.unique.sort

  block: # Grams
    for blk in doc.blocks:
      let ltext = blk.text.to_lower
      ltext.to_bigram_codes blk.bigrams
      ltext.to_trigram_codes blk.trigrams

      unless blk.id.is_empty:
        let lid = blk.id.to_lower
        lid.to_bigram_codes blk.trigrams
        lid.to_trigram_codes blk.trigrams

      for tag in blk.ntags:
        let ltag = tag.decode_tag.to_lower
        ltag.to_bigram_codes blk.bigrams
        ltag.to_trigram_codes blk.trigrams

      blk.bigrams_us = blk.bigrams.unique.sort
      blk.trigrams_us = blk.trigrams.unique.sort

      doc.bigrams_us.add blk.bigrams_us
      doc.trigrams_us.add blk.trigrams_us

    doc.bigrams_us = doc.bigrams_us.unique.sort
    doc.trigrams_us = doc.trigrams_us.unique.sort

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
