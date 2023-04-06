import base

proc parse_tag*(expression: string): Table[string, string] =
  # Parses `"span#id.c1.c2 type=checkbox required"`
  let delimiters = {'#', ' ', '.'}

  proc consume_token(i: var int): string =
    var token = ""
    while i < expression.len and expression[i] notin delimiters:
      token.add expression[i]
      i += 1
    token

  # tag
  var i = 0
  if i < expression.len and expression[i] notin delimiters:
    result["tag"] = consume_token i

  # id
  if i < expression.len and expression[i] == '#':
    i += 1
    result["id"] = consume_token i

  # class
  var classes: seq[string]
  while i < expression.len and expression[i] == '.':
    i += 1
    classes.add consume_token(i)
  if not classes.is_empty: result["class"] = classes.join(" ")

  # other attrs
  var attr_tokens: seq[string]
  while i < expression.len and expression[i] == ' ':
    i += 1
    attr_tokens.add consume_token(i)
  if not attr_tokens.is_empty:
    for token in attr_tokens:
      let tokens = token.split "="
      if tokens.len > 2: throw fmt"invalid attribute '{token}'"
      result[tokens[0]] = if tokens.len > 1: tokens[1] else: "true"

test "parse_tag":
  template check_attrs(tag: string, expected): void =
    check parse_tag(tag) == expected.to_table

  check_attrs "span#id.c1.c2 type=checkbox required", {
    "tag": "span", "id": "id", "class": "c1 c2", "type": "checkbox", "required": "true"
  }
  check_attrs "span", { "tag": "span" }
  check_attrs "#id", { "id": "id" }
  check_attrs ".c1", { "class": "c1" }