import strutils

# format -------------------------------------------------------------------------------------------
proc format*(n: float | int, digits = 2): string =
  format_float(n, format = ff_decimal, precision = digits)