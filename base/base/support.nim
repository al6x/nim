import std/[strformat, sugar, strutils, unicode, tables, macros]
from std/times as nt import nil
from std/nre as nre import nil
from std/options as stdoptions import nil
import ./env as envm
from ./terminal as terminal import nil

export envm


template with*[T](TT: type[T], code) =
  using self: T; using tself: type[T]
  code
  using self: void; using tself: void

template with*(_: string, code) =
  code


type None = object # For optional arguments `proc somefn(v: int | None = none)`
const none = None()


template times*(n: int, code: typed) =
  for _ in 1..n: code


# test ---------------------------------------------------------------------------------------------
let test_enabled_s    = if "test" in env: env["test"] else: "false"
let slow_test_enabled = test_enabled_s == "all"
let test_enabled      = test_enabled_s == "true" or slow_test_enabled

template test*(name: string, body) =
  if test_enabled or name.to_lower == test_enabled_s:
    let pos = instantiation_info()
    echo "  test | " & pos.filename.split(".")[0] & " " & name
    try:
      body
    except Exception as e:
      echo terminal.red("  test | '" & name & "' failed")
      quit(e)

template slow_test*(name: string, body) =
  if slow_test_enabled or name.to_lower == test_enabled_s:
    let pos = instantiation_info()
    echo "  test | " & pos.filename.split(".")[0] & " " & name
    try:
      body
    except Exception as e:
      echo terminal.red("  test | '" & name & "' failed")
      quit(e)


proc if_nil*[T](value, otherwise: T): T =
  if value.is_nil: otherwise else: value


template throw*(message: string) = raise Exception.new_exception(message)
template throw*(exception: Exception | ref Exception) = raise exception


func message*(e: Exception | ref Exception): string = e.msg

# proc quit*(message: string) =
#   stderr.write_line terminal.red(message)
#   # stderr.write_line e.get_stack_trace
#   quit 1
proc quit*(e: Exception | ref Exception) =
  quit e.message


proc ensure*[V](v: V, check: (V) -> bool, message = "check failed"): V =
  if check(v): v else: throw(message)
proc ensure*[V](v: V, check: (V) -> bool, message: () -> string): V =
  if check(v): v else: throw(message())


proc to_ref*[T](o: T): ref T =
  result.new
  result[] = o


# Making the copy intention explicit
func copy*[T](o: T): T = o
func copy*[T](o: ref T): ref T = o[].to_ref


proc to_s*[T](o: T): string = $o


# proc init*[T](_: type[string], v: T): string = $v


template to*[F,T](f: F, _: type[T]): T = T.init(f)


proc align*(n: int, digits: int): string = ($n).align(digits, '0')


proc `$`*[T: typed](x: ref T): string = "->" & $(x[])


func p*(args: varargs[string, `$`]): void = debug_echo args.join(" ")


type Timer* = proc: int
proc timer_sec*(): Timer =
  let started_at = nt.utc(nt.now())
  () => nt.in_seconds(nt.`-`(nt.utc(nt.now()), started_at)).int

proc timer_ms*(): Timer =
  let started_at = nt.utc(nt.now())
  () => nt.in_milliseconds(nt.`-`(nt.utc(nt.now()), started_at)).int


macro check*(conditions: untyped, info = ""): untyped =
  ## Verify if a statement or a list of statements is true.
  ## A helpful error message and set checkpoints are printed out on
  ## failure (if ``outputLevel`` is not ``PRINT_NONE``).
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##  import strutils
  ##
  ##  check("AKB48".toLowerAscii() == "akb48")
  ##
  ##  let teams = {'A', 'K', 'B', '4', '8'}
  ##
  ##  check:
  ##    "AKB48".toLowerAscii() == "akb48"
  ##    'C' in teams
  let checked = callsite()[1]

  template asgn(a: untyped, value: typed) =
    var a = value # XXX: we need "var: var" here in order to
                  # preserve the semantics of var params

  template print(name: untyped, value: typed) =
    when compiles(string($value)):
      echo(name & " was " & $value)

  proc inspectArgs(exp: NimNode): tuple[assigns, check, printOuts: NimNode] =
    result.check = copyNimTree(exp)
    result.assigns = newNimNode(nnkStmtList)
    result.printOuts = newNimNode(nnkStmtList)

    var counter = 0

    if exp[0].kind in {nnkIdent, nnkOpenSymChoice, nnkClosedSymChoice, nnkSym} and
        $exp[0] in ["not", "in", "notin", "==", "<=",
                    ">=", "<", ">", "!=", "is", "isnot", "=~", "!~"]:

      for i in 1 ..< exp.len:
        if exp[i].kind notin nnkLiterals:
          inc counter
          let argStr = exp[i].toStrLit
          let paramAst = exp[i]
          if exp[i].kind == nnkIdent:
            result.printOuts.add getAst(print(argStr, paramAst))
          if exp[i].kind in nnkCallKinds + {nnkDotExpr, nnkBracketExpr, nnkPar}:
            let callVar = newIdentNode(":c" & $counter)
            result.assigns.add getAst(asgn(callVar, paramAst))
            result.check[i] = callVar
            result.printOuts.add getAst(print(argStr, callVar))
          if exp[i].kind == nnkExprEqExpr:
            # ExprEqExpr
            #   Ident !"v"
            #   IntLit 2
            result.check[i] = exp[i][1]
          if exp[i].typeKind notin {ntyTypeDesc}:
            let arg = newIdentNode(":p" & $counter)
            result.assigns.add getAst(asgn(arg, paramAst))
            result.printOuts.add getAst(print(argStr, arg))
            if exp[i].kind != nnkExprEqExpr:
              result.check[i] = arg
            else:
              result.check[i][1] = arg

  case checked.kind
  of nnkCallKinds:

    let (assigns, check, printOuts) = inspectArgs(checked)
    let lineinfo = newStrLitNode(checked.lineInfo)
    let callLit = checked.toStrLit
    let infoLit = info.toStrLit
    result = quote do:
      block:
        `assigns`
        if not `check`:
          echo(`lineinfo` & ": Check failed: " & `callLit` & " " & `infoLit`)
          `printOuts`
          quit()

  of nnkStmtList:
    result = newNimNode(nnkStmtList)
    for node in checked:
      if node.kind != nnkCommentStmt:
        result.add(newCall(newIdentNode("check"), node))

  else:
    let lineinfo = newStrLitNode(checked.lineInfo)
    let callLit = checked.toStrLit
    let infoLit = info.toStrLit

    result = quote do:
      if not `checked`:
        checkpoint(`lineinfo` & ": Check failed: " & `callLit` & " " & `infoLit`)
        quit()

proc to_shared_ptr*[T](v: T): ptr T =
  result = create_shared(T)
  result[] = v

# A simple way to message user by throwing an error
# type MessageError* = object of Exception
# template throw_message*(message: string) =
#   echo terminal.red(message)
#   quit(0)
#   # raise newException(MessageError, message)

# unset --------------------------------------------------------------------------------------------
# type Unset* = object

# const unset* = Unset()

# template is_unset*[T](o: T): bool =
#   when o is Unset: true else: false

# test with group ----------------------------------------------------------------------------------
# var test_group_cache = init_table[string, string]()
# template test*(name: string, group, body) =
#   block:
#     var lname  = name.to_lower
#     var lgroup = group.to_lower
#     if lgroup notin test_group_cache:
#       let tlgroup = "test_" & lgroup
#       test_group_cache[group] = (if tlgroup in env: env[tlgroup] else: "true").to_lower

#     if (test_enabled and test_group_cache[lgroup] == "true") or test_enabled_s == lname:
#       try:
#         body
#       except Exception as e:
#         echo "test '", lname, "' '", lgroup, "' failed"
#         raise e


# aqual --------------------------------------------------------------------------------------------
# proc aqual*(a: float, b: float, epsilon: float): bool =
#   (a - b).abs() <= epsilon


# func error_type*(message: string): string =
#   # Extract error type from string message, the last part of `some text :some_type`
#   let error_type_re = nre.re("(?i).*\\s:([a-z0-9_-]+)$")
#   if stdoptions.is_some(nre.match(message, error_type_re)): nre.split(message, nre.re("\\s:"))[^1]
#   else:                                         ""

# test "error_type":
#   assert "No security definition has been found :not_found".error_type == "not_found"
