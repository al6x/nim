import base

type
  FLink* = tuple[space, doc: string]

  FBlock* = ref object of RootObj
    kind*:     string
    id*:       string # If not set explicitly, will be hash of block's text
    args*:     string
    tags*:     seq[string]
    links*:    seq[FLink]
    assets*:   seq[string]
    glinks*:   seq[string]
    text*:     string
    line_n*:   int
    warns*:    seq[string]

  FSection* = ref object
    title*:    string
    blocks*:   seq[FBlock]
    tags*:     seq[string]
    warns*:    seq[string]
    line_n*:   int

  FDoc* = ref object
    id*:          string
    hash*:        int
    location*:    string
    asset_path*:  string # same as location but without .ft extension
    # space_path*:  string # location dirname
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

  FParagraphKind* = enum text, list
  FParagraph* = object
    case kind*: FParagraphKind
    of text:
      text*: seq[FTextItem]
    of list:
      list*: seq[seq[FTextItem]]

  FTextBlock* = ref object of FBlock
    formatted_text*: seq[FParagraph]

  FListBlock* = ref object of FBlock
    list*: seq[seq[FTextItem]]

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
    raw*: string

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