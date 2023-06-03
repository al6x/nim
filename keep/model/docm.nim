import base

type
  # doc, block -------------------------------------------------------------------------------------
  Link* = tuple[sid, did, bid: string]

  BlockSource* = ref object of RootObj
  DocSource* = ref object of RootObj

  Block* = ref object of RootObj
    id*:     string
    hash*:   int
    tags*:   seq[string]
    links*:  seq[Link]
    assets*: seq[string]
    glinks*: seq[string]
    text*:   string
    warns*:  seq[string]
    source*: BlockSource

  Doc* = ref object
    id*:          string
    hash*:        int
    asset_path*:  Option[string]
    title*:       string
    blocks*:      seq[Block]
    tags*:        seq[string]
    warns*:       seq[string]
    source*:      DocSource

  # blocks -----------------------------------------------------------------------------------------
  ListBlock* = ref object of Block
    list*: seq[Text]

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

  Section* = ref object of Block
    title*: string

  Subsection* = ref object of Block
    title*: string

  TableBlock* = ref object of Block
    header*: Option[seq[Text]]
    rows*:   seq[seq[Text]]
    cols*:   int # number of cols

  # embed ------------------------------------------------------------------------------------------
  Embed* = ref object of RootObj

  ImageEmbed* = ref object of Embed
    path*: string

  CodeEmbed* = ref object of Embed
    code*: string

  UnparsedEmbed* = ref object of Embed
    kind*, body*: string

  # text -------------------------------------------------------------------------------------------
  TextItemKind* = enum text, link, glink, tag, embed
  TextItem* = object
    text*: string
    em*:   Option[bool]
    case kind*: TextItemKind
    of text:  discard
    of link:  link*: Link
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


proc doc_asset_path*(doc_asset_path, relative_asset_path: string): string =
  assert not relative_asset_path.starts_with '/'
  doc_asset_path & "/" & relative_asset_path

proc asset_path*(doc: Doc, asset_path: string): string =
  if doc.asset_path.is_none: throw fmt"Doc doesn't have assets: {doc.id}"
  doc_asset_path(doc.asset_path.get, asset_path)