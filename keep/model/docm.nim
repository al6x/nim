import base, ./schema

type
  Block* = ref object of Record
    assets*: seq[string]
    glinks*: seq[string]
    doc*:    Doc

  Doc* = ref object of Container
    asset_path*: Option[string]
    title*:      string
    blocks*:     seq[Block]
    blockids*:   Table[string, Block] # for quick access by id

  # blocks -----------------------------------------------------------------------------------------
  ListBlock* = ref object of Block
    list*: seq[Text]
    ph*:   bool # display list as paragraphs

  CodeBlock* = ref object of Block
    code*: string

  DataBlock* = ref object of Block
    data*: JsonNode

  ImageBlock* = ref object of Block
    image*: string

  ImagesBlock* = ref object of Block
    images_dir*: string
    images*:     seq[string]
    cols*:       Option[int]

  UnknownBlock* = ref object of Block
    discard

  SectionBlock* = ref object of Block
    title*: string

  TitleBlock* = ref object of Block # A virtual block, for doc title, needed for search
    title*: string

  SubsectionBlock* = ref object of Block
    title*: string

  CardsViewOptions* = object
    cols*:             Option[int]
    img_aspect_ratio*: Option[float]

  TableBlockStyle* = enum table, cards
  TableBlock* = ref object of Block
    header*: Option[seq[Text]]
    rows*:   seq[seq[Text]]
    cols*:   int # number of cols
    style*:  TableBlockStyle
    cards*:  Option[CardsViewOptions]

  # embed ------------------------------------------------------------------------------------------
  Embed* = ref object of RootObj
    kind*, body*: string

  ImageEmbed* = ref object of Embed
    path*: string

  CodeEmbed* = ref object of Embed
    code*: string

  # text -------------------------------------------------------------------------------------------
  TextItemKind* = enum text, link, glink, tag, embed
  TextItem* = object
    text*: string
    em*:   Option[bool]
    case kind*: TextItemKind
    of text:  discard
    of link:  link*: RecordId
    of glink: glink*: string
    of tag:   discard
    of embed: embed*: Embed
  Text* = seq[TextItem]

  ParagraphKind* = enum text, list
  Paragraph* = object
    case kind*: ParagraphKind
    of text: text*: Text
    of list: list*: seq[Text]

  TextBlock* = ref object of Block
    ftext*: seq[Paragraph]

  # sources ----------------------------------------------------------------------------------------
  BlockTextSource* = ref object of RecordSource
    line_n*: (int, int)  # block position in text

  DocTextSource* = ref object of RecordSource
    location*:    string
    tags_line_n*: (int, int)  # tags position in text

proc doc_asset_path*(doc_asset_path, relative_asset_path: string): string =
  assert not relative_asset_path.starts_with '/'
  doc_asset_path & "/" & relative_asset_path

proc asset_path*(doc: Doc, asset_path: string): string =
  if doc.asset_path.is_none: throw fmt"Doc doesn't have assets: {doc.id}"
  doc_asset_path(doc.asset_path.get, asset_path)

proc nwarns*(doc: Doc): seq[string] =
  result.add doc.warns
  for blk in doc.blocks: result.add blk.warns
  result.unique.sort

# add ----------------------------------------------------------------------------------------------
proc post_process(space: Space, doc: Doc) =
  block: # Setting doc and space refs
    doc.space = space
    for blk in doc.blocks:
      blk.doc = doc
      blk.space = space

  block: # Merging parent tags
    let parent_tags = (doc.tags & space.tags).sort
    for blk in doc.blocks:
      blk.tags = (blk.source.tags & parent_tags).unique.sort
      doc.tags.add blk.tags
    doc.tags = doc.tags.unique.sort

proc apdate*(space: Space, doc: Doc) =
  space.post_process doc
  space.records[doc.id] = doc

proc del*(space: Space, doc_id: string) =
  space.records.del doc_id