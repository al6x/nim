# Should be removed once latest changes get into the new nim version

proc handleHexChar(c: char, x: var int): bool {.inline.} =
  ## Converts `%xx` hexadecimal to the ordinal number and adds the result to `x`.
  ## Returns `true` if `c` is hexadecimal.
  ##
  ## When `c` is hexadecimal, the proc is equal to `x = x shl 4 + hex2Int(c)`.
  runnableExamples:
    var x = 0
    assert handleHexChar('a', x)
    assert x == 10

    assert handleHexChar('B', x)
    assert x == 171 # 10 shl 4 + 11

    assert not handleHexChar('?', x)
    assert x == 171 # unchanged
  result = true
  case c
  of '0'..'9': x = (x shl 4) or (ord(c) - ord('0'))
  of 'a'..'f': x = (x shl 4) or (ord(c) - ord('a') + 10)
  of 'A'..'F': x = (x shl 4) or (ord(c) - ord('A') + 10)
  else:
    result = false

proc handleHexChar(c: char): int {.inline.} =
  case c
  of '0'..'9': result = (ord(c) - ord('0'))
  of 'a'..'f': result = (ord(c) - ord('a') + 10)
  of 'A'..'F': result = (ord(c) - ord('A') + 10)
  else: discard

proc decodePercent(s: openArray[char], i: var int): char =
  ## Converts `%xx` hexadecimal to the character with ordinal number `xx`.
  ##
  ## If `xx` is not a valid hexadecimal value, it is left intact: only the
  ## leading `%` is returned as-is, and `xx` characters will be processed in the
  ## next step (e.g. in `uri.decodeUrl`) as regular characters.
  result = '%'
  if i+2 < s.len:
    var x = 0
    if handleHexChar(s[i+1], x) and handleHexChar(s[i+2], x):
      result = chr(x)
      inc(i, 2)

iterator decodeQuery*(data: string): tuple[key, value: string] =
  ## Reads and decodes query string `data` and yields the `(key, value)` pairs
  ## the data consists of. If compiled with `-d:nimLegacyParseQueryStrict`, an
  ## error is raised when there is an unencoded `=` character in a decoded
  ## value, which was the behavior in Nim < 1.5.1
  runnableExamples:
    import std/sequtils
    doAssert toSeq(decodeQuery("foo=1&bar=2=3")) == @[("foo", "1"), ("bar", "2=3")]
    doAssert toSeq(decodeQuery("&a&=b&=&&")) == @[("", ""), ("a", ""), ("", "b"), ("", ""), ("", "")]

  proc parseData(data: string, i: int, field: var string, sep: char): int =
    result = i
    while result < data.len:
      let c = data[result]
      case c
      of '%': add(field, decodePercent(data, result))
      of '+': add(field, ' ')
      of '&': break
      else:
        if c == sep: break
        else: add(field, data[result])
      inc(result)

  var i = 0
  var name = ""
  var value = ""
  # decode everything in one pass:
  while i < data.len:
    setLen(name, 0) # reuse memory
    i = parseData(data, i, name, '=')
    setLen(value, 0) # reuse memory
    if i < data.len and data[i] == '=':
      inc(i) # skip '='
      when defined(nimLegacyParseQueryStrict):
        i = parseData(data, i, value, '=')
      else:
        i = parseData(data, i, value, '&')
    yield (name, value)
    if i < data.len:
      when defined(nimLegacyParseQueryStrict):
        if data[i] != '&':
          uriParseError("'&' expected at index '$#' for '$#'" % [$i, data])
      inc(i)