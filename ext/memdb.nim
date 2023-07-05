import base

template define_code*(Code, Source, Underneath) =
  type Code = distinct Underneath

  proc `$`*(code: Code): string {.borrow.}
  proc hash*(code: Code): Hash {.borrow.}
  proc `<`*(a, b: Code): bool {.borrow.}
  proc `<=`*(a, b: Code): bool {.borrow.}
  proc `==`*(a, b: Code): bool {.borrow.}
  proc `-`*(code: Code, dec: int): Code = (code.Underneath - dec.Underneath).Code
  proc `+`*(code: Epoch, inc: int): Code = (code.Underneath + inc.Underneath).Code

  var code_to_source: seq[Source]
  var source_to_code: Table[Source, Code]
  proc code*(source: Source): Code =
    result = source_to_code.mget_or_put(source, source_to_code.len.Code)
    if source_to_code.len > code_to_source.len: code_to_source.add source
  proc source*(code: Code): Source =
    code_to_source[code.Underneath]

template define_int16_code*(Code, Source) =
  define_code Code, Source, int16

when is_main_module:
  define_int16_code IdCode, string

  let zid = "Zeratul".code
  let tid = "Tassadar".code
  check (zid, tid) == (0.IdCode, 1.IdCode)
  check zid.source == "Zeratul"
  check tid.source == "Tassadar"