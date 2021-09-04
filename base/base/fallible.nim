require std/sugar
require ./[support, option, table, json]

type Fallible*[T] = object
  case is_error*: bool
  of true:
    message*: string
  of false:
    value*: T


func is_success*[T](e: Fallible[T]): bool = not e.is_error
func is_error*[T](e: Fallible[T]): bool = e.is_error

func is_empty*[T](e: Fallible[T]): bool {.inline.} = e.is_error
func is_blank*[T](e: Fallible[T]): bool {.inline.} = e.is_error
func is_present*[T](e: Fallible[T]): bool {.inline.} = not e.is_error


func get*[T](e: Fallible[T]): T =
  if e.is_error: throw(e.message) else: e.value


func error*(T: type, message: string): Fallible[T] = Fallible[T](is_error: true, message: message)


func success*[T](value: T): Fallible[T] = Fallible[T](is_error: false, value: value)

func success*[T](value: Option[T]): Fallible[T] = Fallible[T](is_error: false, value: value.get)

# func set*[T](value: T): Fallible[T] = Fallible[T](is_error: false, value: value)

# func set*[T](value: Option[T]): Fallible[T] = Fallible[T](is_error: false, value: value.get)


# Used in `a.to(Fallible[B])` conversions
proc init*[B, A](_: type[Fallible[B]], a: Fallible[A]): Fallible[B] =
  assert a.is_error, "init possible for errors only"
  B.error(a.message)

test "init":
  discard Fallible[string].init(int.error("some error"))
  discard int.error("some error").to(Fallible[float])


func errors*[T](list: seq[Fallible[T]]): seq[string] =
  list.filter_map(proc (e: Fallible[T]): auto =
    if e.is_error: e.message.some else: string.none
  )

func errors*[K, V](table: Table[K, Fallible[V]] | ref Table[K, Fallible[V]]): Table[K, string] =
  table.filter_map(proc (e: Fallible[V]): auto =
    if e.is_error: e.message.some else: string.none
  )


func successes*[T](list: seq[Fallible[T]]): seq[T] =
  for v in list:
    if v.is_present:
      result.add v.get

func successes*[K, V](table: Table[K, Fallible[V]] | ref Table[K, Fallible[V]]): Table[K, V] =
  table.filter_map(proc (e: Fallible[V]): auto =
    if e.is_error: V.none else: e.value.some
  )


proc map*[A, B](a: Fallible[A], op: (A) -> B): Fallible[B] =
  if a.is_success: op(a.get).success else: B.error(a.message)


converter to_option*[T](v: Fallible[T]): Option[T] =
  if v.is_present: v.get.some else: T.none

# proc `%`*[T](f: Fallible[T]): JsonNode =
#   if f.is_error: %f else: %(f.get)

proc from_json_hook*[T](v: var Fallible[T], json: JsonNode) =
  v = if json.kind == JObject and "is_error" in json:
    if json["is_error"].get_bool:
      let message =
        if   "error"   in json: json["error"].get_str
        elif "message" in json: json["message"].get_str
        else:                   "unknown error"
      T.error message
    else:
      json["value"].json_to(T).success
  else:
    json.json_to(T).success

proc to_json_hook*[T](v: Fallible[T]): JsonNode =
  if v.is_error: (is_error: true, message: v.message).to_json
  else:          v.get.to_json