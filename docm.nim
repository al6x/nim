import sequtils, strutils, strformat

type
  DocPriority* = enum high_e, normal_e, low_e

  DocKind* = enum text_e, todo_e

  DocItem* = object
    case kind: DocKind

    of text_e:
      title: string
      text:  string

    of todo_e:
      todo:     string
      priority: DocPriority

    tags: seq[string]

converter to_doc_level*(s: string): DocPriority = parse_enum[DocPriority](fmt"{s}_e")

var docs*: seq[DocItem]

proc doc*(title: string, text: string, tags: openarray[string] = []): void =
  docs.add DocItem(kind: text_e, title: title, text: text, tags: tags.to_seq)

proc todo*(todo: string, priority: DocPriority = normal_e, tags: openarray[string] = []): void =
  docs.add DocItem(kind: todo_e, priority: priority, tags: tags.to_seq)