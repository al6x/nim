import sequtils, strutils, strformat

type
  TodoPriority* = enum high, normal, low

  DocKind* = enum text, todo

  DocItem* = object
    tags: seq[string]
    text: string

    case kind: DocKind
    of text:
      title:    string
    of todo:
      priority: TodoPriority

converter to_doc_level*(s: string): TodoPriority = parse_enum[TodoPriority](fmt"{s}_e")

var docs*: seq[DocItem]

proc doc*(title: string, text: string, tags: openarray[string] = []): void =
  docs.add DocItem(kind: DocKind.text, title: title, text: text, tags: tags.to_seq)

proc todo*(text: string, priority: TodoPriority = normal, tags: openarray[string] = []): void =
  docs.add DocItem(kind: todo, text: text, priority: priority, tags: tags.to_seq)