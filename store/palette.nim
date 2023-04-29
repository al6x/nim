import base, mono/core

proc app*(left, right: seq[HtmlElement]): HtmlElement =
  h".w-full.min-h-screen.flex":
    + h".w-9/12": # .z-10
      + left
    + h".w-3/12.relative .border-gray-300.border-l.bg-slate-50": # z-0.
      + right
