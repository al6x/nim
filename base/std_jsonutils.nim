# Change begin -------------------------------------------------------------------------------------
# Fixing std/jsonutils
# Change end ---------------------------------------------------------------------------------------


##[
This module implements a hookable (de)serialization for arbitrary types.
Design goal: avoid importing modules where a custom serialization is needed;
see strtabs.fromJsonHook,toJsonHook for an example.
]##

runnableExamples:
  import std/[strtabs,json]
  type Foo = ref object
    t: bool
    z1: int8
  let a = (1.5'f32, (b: "b2", a: "a2"), 'x', @[Foo(t: true, z1: -3), nil], [{"name": "John"}.newStringTable])
  let j = a.toJson
  doAssert j.jsonTo(type(a)).toJson == j

import std/[json,strutils,tables,sets,strtabs,options]

#[
Future directions:
add a way to customize serialization, for e.g.:
* field renaming
* allow serializing `enum` and `char` as `string` instead of `int`
  (enum is more compact/efficient, and robust to enum renamings, but string
  is more human readable)
* handle cyclic references, using a cache of already visited addresses
* implement support for serialization and de-serialization of nested variant
  objects.
]#

import std/macros


# Change begin -------------------------------------------------------------------------------------
proc newJRawNumber(s: string): JsonNode =
  ## Creates a "raw JS number", that is a number that does not
  ## fit into Nim's ``BiggestInt`` field. This is really a `JString`
  ## with the additional information that it should be converted back
  ## to the string representation without the quotes.
  # result = JsonNode(kind: JString, str: s, isUnquoted: true)

  # Can't be used because `isUnquoted` is private field and can't be set from here
  raise newException(KeyError, "not supported, fix it")

proc to_json_default*(s: string): JsonNode =
  ## Generic constructor for JSON data. Creates a new `JString JsonNode`.
  result = JsonNode(kind: JString, str: s)

proc to_json_default*(n: uint): JsonNode =
  ## Generic constructor for JSON data. Creates a new `JInt JsonNode`.
  if n > cast[uint](int.high):
    result = newJRawNumber($n)
  else:
    result = JsonNode(kind: JInt, num: BiggestInt(n))

proc to_json_default*(n: int): JsonNode =
  ## Generic constructor for JSON data. Creates a new `JInt JsonNode`.
  result = JsonNode(kind: JInt, num: n)

proc to_json_default*(n: BiggestUInt): JsonNode =
  ## Generic constructor for JSON data. Creates a new `JInt JsonNode`.
  if n > cast[BiggestUInt](BiggestInt.high):
    result = newJRawNumber($n)
  else:
    result = JsonNode(kind: JInt, num: BiggestInt(n))

proc to_json_default*(n: BiggestInt): JsonNode =
  ## Generic constructor for JSON data. Creates a new `JInt JsonNode`.
  result = JsonNode(kind: JInt, num: n)

proc to_json_default*(n: float): JsonNode =
  ## Generic constructor for JSON data. Creates a new `JFloat JsonNode`.
  result = JsonNode(kind: JFloat, fnum: n)

proc to_json_default*(b: bool): JsonNode =
  ## Generic constructor for JSON data. Creates a new `JBool JsonNode`.
  result = JsonNode(kind: JBool, bval: b)

# proc `%`*(keyVals: openArray[tuple[key: string, val: JsonNode]]): JsonNode =
#   ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
#   if keyVals.len == 0: return newJArray()
#   result = newJObject()
#   for key, val in items(keyVals): result.fields[key] = val

proc to_json_default*(j: JsonNode): JsonNode = j

# proc `%`*[T](elements: openArray[T]): JsonNode =
#   ## Generic constructor for JSON data. Creates a new `JArray JsonNode`
#   result = newJArray()
#   for elem in elements: result.add(%elem)

proc to_json_default*[T](table: Table[string, T]|OrderedTable[string, T]): JsonNode =
  ## Generic constructor for JSON data. Creates a new ``JObject JsonNode``.
  result = newJObject()
  for k, v in table: result[k] = v.to_json

# proc `%`*[T](opt: Option[T]): JsonNode =
#   ## Generic constructor for JSON data. Creates a new ``JNull JsonNode``
#   ## if ``opt`` is empty, otherwise it delegates to the underlying value.
#   if opt.isSome: %opt.get else: newJNull()

# proc `%`*[T: object](o: T): JsonNode =
#   ## Construct JsonNode from tuples and objects.
#   result = newJObject()
#   for k, v in o.fieldPairs: result[k] = %v

# proc `%`*(o: ref object): JsonNode =
#   ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
#   if o.isNil:
#     result = newJNull()
#   else:
#     result = %(o[])

proc to_json_default*(o: enum): JsonNode =
  ## Construct a JsonNode that represents the specified enum value as a
  ## string. Creates a new ``JString JsonNode``.
  result = to_json_default($o)
# Change end ---------------------------------------------------------------------------------------



# Change begin -------------------------------------------------------------------------------------
# proc to_json_hook*(n: JsonNode): JsonNode =
#   n

# proc to_json_default*[T: tuple](o: T): JsonNode =
#   result = new_JObject()
#   for k, v in o.field_pairs: result[k] = v.to_json
# Change end ---------------------------------------------------------------------------------------


type
  Joptions* = object
    ## Options controlling the behavior of `fromJson`.
    allowExtraKeys*: bool
      ## If `true` Nim's object to which the JSON is parsed is not required to
      ## have a field for every JSON key.
    allowMissingKeys*: bool
      ## If `true` Nim's object to which JSON is parsed is allowed to have
      ## fields without corresponding JSON keys.
    # in future work: a key rename could be added

proc isNamedTuple(T: typedesc): bool {.magic: "TypeTrait".}
proc distinctBase(T: typedesc): typedesc {.magic: "TypeTrait".}
template distinctBase[T](a: T): untyped = distinctBase(type(a))(a)

macro getDiscriminants(a: typedesc): seq[string] =
  ## return the discriminant keys
  # candidate for std/typetraits
  var a = a.getTypeImpl
  doAssert a.kind == nnkBracketExpr
  let sym = a[1]
  let t = sym.getTypeImpl
  let t2 = t[2]
  doAssert t2.kind == nnkRecList
  result = newTree(nnkBracket)
  for ti in t2:
    if ti.kind == nnkRecCase:
      let key = ti[0][0]
      let typ = ti[0][1]
      result.add newLit key.strVal
  if result.len > 0:
    result = quote do:
      @`result`
  else:
    result = quote do:
      seq[string].default

macro initCaseObject(T: typedesc, fun: untyped): untyped =
  ## does the minimum to construct a valid case object, only initializing
  ## the discriminant fields; see also `getDiscriminants`
  # maybe candidate for std/typetraits
  var a = T.getTypeImpl
  doAssert a.kind == nnkBracketExpr
  let sym = a[1]
  let t = sym.getTypeImpl
  var t2: NimNode
  case t.kind
  of nnkObjectTy: t2 = t[2]
  of nnkRefTy: t2 = t[0].getTypeImpl[2]
  else: doAssert false, $t.kind # xxx `nnkPtrTy` could be handled too
  doAssert t2.kind == nnkRecList
  result = newTree(nnkObjConstr)
  result.add sym
  for ti in t2:
    if ti.kind == nnkRecCase:
      let key = ti[0][0]
      let typ = ti[0][1]
      let key2 = key.strVal
      let val = quote do:
        `fun`(`key2`, typedesc[`typ`])
      result.add newTree(nnkExprColonExpr, key, val)

proc raiseJsonException(condStr: string, msg: string) {.noinline.} =
  # just pick 1 exception type for simplicity; other choices would be:
  # JsonError, JsonParser, JsonKindError
  raise newException(ValueError, condStr & " failed: " & msg)

template checkJson(cond: untyped, msg = "") =
  if not cond:
    raiseJsonException(astToStr(cond), msg)

proc hasField[T](obj: T, field: string): bool =
  for k, _ in fieldPairs(obj):
    if k == field:
      return true
  return false

macro accessField(obj: typed, name: static string): untyped =
  newDotExpr(obj, ident(name))

template fromJsonFields(newObj, oldObj, json, discKeys, opt) =
  type T = typeof(newObj)
  # we could customize whether to allow JNull
  checkJson json.kind == JObject, $json.kind
  var num, numMatched = 0
  for key, val in fieldPairs(newObj):
    num.inc
    when key notin discKeys:
      if json.hasKey key:
        numMatched.inc
        fromJson(val, json[key])
# Change begin -------------------------------------------------------------------------------------
# Allowing field Option[T] to be missing
      elif val is Option:
        num.dec
        fromJson(val, newJNull())
# Change end ---------------------------------------------------------------------------------------
      elif opt.allowMissingKeys:
        # if there are no discriminant keys the `oldObj` must always have the
        # same keys as the new one. Otherwise we must check, because they could
        # be set to different branches.
        when typeof(oldObj) isnot typeof(nil):
          if discKeys.len == 0 or hasField(oldObj, key):
            val = accessField(oldObj, key)
      else:
        checkJson false, $($T, key, json)
    else:
      if json.hasKey key:
        numMatched.inc
  let ok =
# Change begin -------------------------------------------------------------------------------------
# Always allowing extra keys as option passing is broken in jsonutils
    # if opt.allowExtraKeys and opt.allowMissingKeys:
    if true and opt.allowMissingKeys:
      true
    # elif opt.allowExtraKeys:
    elif true:
# Change end ---------------------------------------------------------------------------------------
      # This check is redundant because if here missing keys are not allowed,
      # and if `num != numMatched` it will fail in the loop above but it is left
      # for clarity.
      assert num == numMatched
      num == numMatched
    elif opt.allowMissingKeys:
      json.len == numMatched
    else:
      json.len == num and num == numMatched

  checkJson ok, $(json.len, num, numMatched, $T, json)

proc fromJson*[T](a: var T, b: JsonNode, opt = Joptions())

proc discKeyMatch[T](obj: T, json: JsonNode, key: static string): bool =
  if not json.hasKey key:
    return true
  let field = accessField(obj, key)
  var jsonVal: typeof(field)
  fromJson(jsonVal, json[key])
  if jsonVal != field:
    return false
  return true

macro discKeysMatchBodyGen(obj: typed, json: JsonNode,
                           keys: static seq[string]): untyped =
  result = newStmtList()
  let r = ident("result")
  for key in keys:
    let keyLit = newLit key
    result.add quote do:
      `r` = `r` and discKeyMatch(`obj`, `json`, `keyLit`)

proc discKeysMatch[T](obj: T, json: JsonNode, keys: static seq[string]): bool =
  result = true
  discKeysMatchBodyGen(obj, json, keys)

proc fromJson*[T](a: var T, b: JsonNode, opt = Joptions()) =
  ## inplace version of `jsonTo`
  #[
  adding "json path" leading to `b` can be added in future work.
  ]#
  checkJson b != nil, $($T, b)
  when compiles(fromJsonHook(a, b)): fromJsonHook(a, b)
# Change begin -------------------------------------------------------------------------------------
  elif compiles(fromJsonHook(T, b)): a = fromJsonHook(T, b)
# Change end ---------------------------------------------------------------------------------------
  elif T is bool: a = to(b,T)
  elif T is enum:
    case b.kind
    of JInt: a = T(b.getBiggestInt())
    of JString: a = parseEnum[T](b.getStr())
    else: checkJson false, $($T, " ", b)
  elif T is uint|uint64: a = T(to(b, uint64))
  elif T is Ordinal: a = cast[T](to(b, int))
  elif T is pointer: a = cast[pointer](to(b, int))
  elif T is distinct:
    when nimvm:
      # bug, potentially related to https://github.com/nim-lang/Nim/issues/12282
      a = T(jsonTo(b, distinctBase(T)))
    else:
      a.distinctBase.fromJson(b)
  elif T is string|SomeNumber: a = to(b,T)
  elif T is JsonNode: a = b
  elif T is ref | ptr:
    if b.kind == JNull: a = nil
    else:
      a = T()
      fromJson(a[], b)
  elif T is array:
    checkJson a.len == b.len, $(a.len, b.len, $T)
    var i = 0
    for ai in mitems(a):
      fromJson(ai, b[i])
      i.inc
  elif T is seq:
    a.setLen b.len
    for i, val in b.getElems:
      fromJson(a[i], val)
  elif T is object:
    template fun(key, typ): untyped {.used.} =
      if b.hasKey key:
        jsonTo(b[key], typ)
      elif hasField(a, key):
        accessField(a, key)
      else:
        default(typ)
    const keys = getDiscriminants(T)
    when keys.len == 0:
      fromJsonFields(a, nil, b, keys, opt)
    else:
      if discKeysMatch(a, b, keys):
        fromJsonFields(a, nil, b, keys, opt)
      else:
        var newObj = initCaseObject(T, fun)
        fromJsonFields(newObj, a, b, keys, opt)
        a = newObj
  elif T is tuple:
    when isNamedTuple(T):
      fromJsonFields(a, nil, b, seq[string].default, opt)
    else:
      checkJson b.kind == JArray, $(b.kind) # we could customize whether to allow JNull
      var i = 0
      for val in fields(a):
        fromJson(val, b[i])
        i.inc
      checkJson b.len == i, $(b.len, i, $T, b) # could customize
  else:
    # checkJson not appropriate here
    static: doAssert false, "not yet implemented: " & $T

proc jsonTo*(b: JsonNode, T: typedesc): T =
  ## reverse of `toJson`
  fromJson(result, b)

proc toJson*[T](a: T): JsonNode =
  ## serializes `a` to json; uses `toJsonHook(a: T)` if it's in scope to
  ## customize serialization, see strtabs.toJsonHook for an example.
  when compiles(toJsonHook(a)): result = toJsonHook(a)
# Change begin -------------------------------------------------------------------------------------
  elif T is JsonNode: result = a
# Change ends --------------------------------------------------------------------------------------
  elif T is object | tuple:
    when T is object or isNamedTuple(T):
      result = newJObject()
      for k, v in a.fieldPairs:
# Change begin -------------------------------------------------------------------------------------
# Don't printing Option or nil
        when typeof(v) is Option:
          if v.is_some:
            result[k] = toJson(v)
        elif typeof(v) is type typeof(nil):
          discard
        else:
          result[k] = toJson(v)
# Change end ---------------------------------------------------------------------------------------
    else:
      result = newJArray()
      for v in a.fields: result.add toJson(v)
  elif T is ref | ptr:
    if system.`==`(a, nil): result = newJNull()
    else: result = toJson(a[])
  elif T is array | seq:
    result = newJArray()
    for ai in a: result.add toJson(ai)
  elif T is pointer: result = toJson(cast[int](a))
    # edge case: `a == nil` could've also led to `newJNull()`, but this results
    # in simpler code for `toJson` and `fromJson`.
  elif T is distinct: result = toJson(a.distinctBase)
  elif T is bool: result = a.to_json_default
  elif T is SomeInteger: result = a.to_json_default
# Change begin -------------------------------------------------------------------------------------
# Enums should be saved as string by default, not as ordinal
  elif T is enum: result = a.to_json_default
# Change end ---------------------------------------------------------------------------------------
  elif T is Ordinal: result = a.ord.to_json_default
  else: result = a.to_json_default

proc fromJsonHook*[K, V](t: var (Table[K, V] | OrderedTable[K, V]),
                         jsonNode: JsonNode) =
  ## Enables `fromJson` for `Table` and `OrderedTable` types.
  ##
  ## See also:
  ## * `toJsonHook proc<#toJsonHook,(Table[K,V]|OrderedTable[K,V])>`_
  runnableExamples:
    import tables, json
    var foo: tuple[t: Table[string, int], ot: OrderedTable[string, int]]
    fromJson(foo, parseJson("""
      {"t":{"two":2,"one":1},"ot":{"one":1,"three":3}}"""))
    assert foo.t == [("one", 1), ("two", 2)].toTable
    assert foo.ot == [("one", 1), ("three", 3)].toOrderedTable

  assert jsonNode.kind == JObject,
          "The kind of the `jsonNode` must be `JObject`, but its actual " &
          "type is `" & $jsonNode.kind & "`."
  clear(t)
  for k, v in jsonNode:
    t[k] = jsonTo(v, V)

proc toJsonHook*[K, V](t: (Table[K, V] | OrderedTable[K, V])): JsonNode =
  ## Enables `toJson` for `Table` and `OrderedTable` types.
  ##
  ## See also:
  ## * `fromJsonHook proc<#fromJsonHook,(Table[K,V]|OrderedTable[K,V]),JsonNode>`_
  runnableExamples:
    import tables, json
    let foo = (
      t: [("two", 2)].toTable,
      ot: [("one", 1), ("three", 3)].toOrderedTable)
    assert $toJson(foo) == """{"t":{"two":2},"ot":{"one":1,"three":3}}"""

  result = newJObject()
  for k, v in pairs(t):
    result[k] = toJson(v)

proc fromJsonHook*[A](s: var SomeSet[A], jsonNode: JsonNode) =
  ## Enables `fromJson` for `HashSet` and `OrderedSet` types.
  ##
  ## See also:
  ## * `toJsonHook proc<#toJsonHook,SomeSet[A]>`_
  runnableExamples:
    import sets, json
    var foo: tuple[hs: HashSet[string], os: OrderedSet[string]]
    fromJson(foo, parseJson("""
      {"hs": ["hash", "set"], "os": ["ordered", "set"]}"""))
    assert foo.hs == ["hash", "set"].toHashSet
    assert foo.os == ["ordered", "set"].toOrderedSet

  assert jsonNode.kind == JArray,
          "The kind of the `jsonNode` must be `JArray`, but its actual " &
          "type is `" & $jsonNode.kind & "`."
  clear(s)
  for v in jsonNode:
    incl(s, jsonTo(v, A))

proc toJsonHook*[A](s: SomeSet[A]): JsonNode =
  ## Enables `toJson` for `HashSet` and `OrderedSet` types.
  ##
  ## See also:
  ## * `fromJsonHook proc<#fromJsonHook,SomeSet[A],JsonNode>`_
  runnableExamples:
    import sets, json
    let foo = (hs: ["hash"].toHashSet, os: ["ordered", "set"].toOrderedSet)
    assert $toJson(foo) == """{"hs":["hash"],"os":["ordered","set"]}"""

  result = newJArray()
  for k in s:
    add(result, toJson(k))

proc fromJsonHook*[T](self: var Option[T], jsonNode: JsonNode) =
  ## Enables `fromJson` for `Option` types.
  ##
  ## See also:
  ## * `toJsonHook proc<#toJsonHook,Option[T]>`_
  runnableExamples:
    import options, json
    var opt: Option[string]
    fromJsonHook(opt, parseJson("\"test\""))
    assert get(opt) == "test"
    fromJson(opt, parseJson("null"))
    assert isNone(opt)

  if jsonNode.kind != JNull:
    self = some(jsonTo(jsonNode, T))
  else:
    self = none[T]()

proc toJsonHook*[T](self: Option[T]): JsonNode =
  ## Enables `toJson` for `Option` types.
  ##
  ## See also:
  ## * `fromJsonHook proc<#fromJsonHook,Option[T],JsonNode>`_
  runnableExamples:
    import options, json
    let optSome = some("test")
    assert $toJson(optSome) == "\"test\""
    let optNone = none[string]()
    assert $toJson(optNone) == "null"

  if isSome(self):
    toJson(get(self))
  else:
    newJNull()

proc fromJsonHook*(a: var StringTableRef, b: JsonNode) =
  ## Enables `fromJson` for `StringTableRef` type.
  ##
  ## See also:
  ## * `toJsonHook` proc<#toJsonHook,StringTableRef>`_
  runnableExamples:
    import strtabs, json
    var t = newStringTable(modeCaseSensitive)
    let jsonStr = """{"mode": 0, "table": {"name": "John", "surname": "Doe"}}"""
    fromJsonHook(t, parseJson(jsonStr))
    assert t[] == newStringTable("name", "John", "surname", "Doe",
                                 modeCaseSensitive)[]

  var mode = jsonTo(b["mode"], StringTableMode)
  a = newStringTable(mode)
  let b2 = b["table"]
  for k,v in b2: a[k] = jsonTo(v, string)

proc toJsonHook*(a: StringTableRef): JsonNode =
  ## Enables `toJson` for `StringTableRef` type.
  ##
  ## See also:
  ## * `fromJsonHook` proc<#fromJsonHook,StringTableRef,JsonNode>`_
  runnableExamples:
    import strtabs, json
    let t = newStringTable("name", "John", "surname", "Doe", modeCaseSensitive)
    let jsonStr = """{"mode": "modeCaseSensitive",
                      "table": {"name": "John", "surname": "Doe"}}"""
    assert toJson(t) == parseJson(jsonStr)

  result = newJObject()
  result["mode"] = toJson($a.mode)
  let t = newJObject()
  for k,v in a: t[k] = toJson(v)
  result["table"] = t
