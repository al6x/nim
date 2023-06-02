import base

type
  FLink* = tuple[space, doc: string]

  FRawBlock* = object
    text*, kind*, id*, args*: string
    lines*: (int, int) # block position in text

  FBlock* = ref object of RootObj
    id*:     string
    hash*:   int         # hash of block's text
    tags*:   seq[string]
    links*:  seq[FLink]
    assets*: seq[string]
    glinks*: seq[string]
    text*:   string
    warns*:  seq[string]
    raw*:    FRawBlock

  FSection* = ref object
    title*:  string
    blocks*: seq[FBlock]
    tags*:   seq[string]
    warns*:  seq[string]
    raw*:    FRawBlock

  FDoc* = ref object
    id*:          string
    hash*:        int    # hash of docs's text
    location*:    string
    asset_path*:  string # same as location but without .ft extension
    title*:       string
    sections*:    seq[FSection]
    tags*:        seq[string]
    tags_line_n*: int
    warns*:       seq[string]

  FTextItemKind* = enum text, link, glink, tag, embed
  FTextItem* = object
    text*: string
    em*:   Option[bool]
    case kind*: FTextItemKind
    of text:
      discard
    of link:
      link*: FLink
    of glink:
      glink*: string
    of tag:
      discard
    of embed:
      embed_kind*: string
      parsed*:     Option[JsonNode]
  FInlineText* = seq[FTextItem]

  FParagraphKind* = enum text, list
  FParagraph* = object
    case kind*: FParagraphKind
    of text:
      text*: FInlineText
    of list:
      list*: seq[FInlineText]

  FTextBlock* = ref object of FBlock
    formatted_text*: seq[FParagraph]

  FListBlock* = ref object of FBlock
    list*: seq[FInlineText]

  FCodeBlock* = ref object of FBlock
    code*: string

  FDataBlock* = ref object of FBlock
    data*: JsonNode

  FImageBlock* = ref object of FBlock
    image*: string

  FImagesBlock* = ref object of FBlock
    images_dir*: string
    images*:     seq[string]

  FUnknownBlock* = ref object of FBlock
    discard

  FSubsection* = ref object of FBlock
    title*:  string

  FTableBlock* = ref object of FBlock
    header*: Option[seq[FInlineText]]
    rows*:   seq[seq[FInlineText]]
    cols*:   int # number of cols

proc init*(_: type[FDoc], location: string): FDoc =
  assert location.ends_with ".ft"
  let id = location.file_name.file_name_ext.name
  # space_path: location.parent_dir
  FDoc(id: id, title: id, location: location, asset_path: location[0..^4])

proc fdoc_asset_path*(fdoc_asset_path, relative_path: string): string =
  assert not relative_path.starts_with '/'
  fdoc_asset_path & "/" & relative_path

proc asset_path*(doc: FDoc, relative_path: string): string =
  fdoc_asset_path(doc.asset_path, relative_path)