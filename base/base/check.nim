# Copied from std/unittest
import std/macros

macro check*(conditions: untyped): untyped =
  ## Verify if a statement or a list of statements is true.
  ## A helpful error message and set checkpoints are printed out on
  ## failure (if ``outputLevel`` is not ``PRINT_NONE``).
  runnableExamples:
    import std/strutils

    check("AKB48".toLowerAscii() == "akb48")

    let teams = {'A', 'K', 'B', '4', '8'}

    check:
      "AKB48".toLowerAscii() == "akb48"
      'C' notin teams

  let checked = callsite()[1]

  template asgn(a: untyped, value: typed) =
    var a = value # XXX: we need "var: var" here in order to
                  # preserve the semantics of var params

  template print(name: untyped, value: typed) =
    when compiles(string($value)):
      echo name & " was " & $value

  proc inspectArgs(exp: NimNode): tuple[assigns, check, printOuts: NimNode] =
    result.check = copyNimTree(exp)
    result.assigns = newNimNode(nnkStmtList)
    result.printOuts = newNimNode(nnkStmtList)

    var counter = 0

    if exp[0].kind in {nnkIdent, nnkOpenSymChoice, nnkClosedSymChoice, nnkSym} and
        $exp[0] in ["not", "in", "notin", "==", "<=",
                    ">=", "<", ">", "!=", "is", "isnot"]:

      for i in 1 ..< exp.len:
        if exp[i].kind notin nnkLiterals:
          inc counter
          let argStr = exp[i].toStrLit
          let paramAst = exp[i]
          if exp[i].kind == nnkIdent:
            result.printOuts.add getAst(print(argStr, paramAst))
          if exp[i].kind in nnkCallKinds + {nnkDotExpr, nnkBracketExpr, nnkPar} and
                  (exp[i].typeKind notin {ntyTypeDesc} or $exp[0] notin ["is", "isnot"]):
            let callVar = newIdentNode(":c" & $counter)
            result.assigns.add getAst(asgn(callVar, paramAst))
            result.check[i] = callVar
            result.printOuts.add getAst(print(argStr, callVar))
          if exp[i].kind == nnkExprEqExpr:
            # ExprEqExpr
            #   Ident "v"
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
    result = quote do:
      block:
        `assigns`
        if not `check`:
          echo "\e[31m" & "Failed: " & `callLit` & "\e[0m" & " " & "\e[90m" & `lineinfo` & "\e[0m"
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

    result = quote do:
      if not `checked`:
        echo "\e[31m" & "Failed: " & `callLit` & "\e[0m" & " " & "\e[90m" & `lineinfo` & "\e[0m"
        quit()
