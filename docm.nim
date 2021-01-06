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

var docs*: seq[DocItem]

proc doc*(title: string, text: string, tags: seq[string] = @[]): void =
  docs.add DocItem(kind: text_e, title: title, text: text, tags: tags)

proc todo*(todo: string, priority: DocPriority = normal_e, tags: seq[string] = @[]): void =
  docs.add DocItem(kind: todo_e, priority: priority, tags: tags)