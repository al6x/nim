import std/[math, sequtils, strformat, sugar, options]
import ./support, ./algorithm, ./enumm, ./seqm

export math


type P2* = tuple[x: float, y: float] # 2D Point


func `*`*(a: float, b: (float, float)): (float, float) =
  (a * b[0], a * b[1])

func `+`*(a: float, b: (float, float)): (float, float) =
  (a + b[0], a + b[1])


func `+`*(a: (float, float), b: (float, float)): (float, float) =
  (a[0] + b[0], a[1] + b[1])


func `+=`*(a: var (float, float), b: (float, float))=
  a = (a[0] + b[0], a[1] + b[1])

func `/=`*(a: var (float, float), b: float)=
  a = (a[0] / b, a[1] / b)



func rsim*(a: float, b: float): float =
  assert a.sgn == b.sgn, "rdif requires same sign"
  let (aabs, babs) = (a.abs, b.abs)
  let (smaller, larger) = (min(aabs, babs), max(aabs, babs))
  smaller / larger

test "rsim":
  assert rsim(1.0, 1.0009).to_s == "0.9991008092716556"


const requal_default_rsim = 0.999
const requal_min_float    = MinFloatNormal / requal_default_rsim
func requal*(a: float, b: float, rsim: float = requal_default_rsim): bool =
  if a == b:
    true
  elif a.sgn != b.sgn:
    false
  else:
    let aabs = a.abs
    let babs = b.abs
    let (smaller, larger) = (min(aabs, babs), max(aabs, babs))
    if larger < requal_min_float: true
    else:                         (smaller / larger) > rsim

func requal*[T](a: seq[T], b: seq[T], rsim: float = requal_default_rsim): bool =
  for i, ai in a:
    if not ai.requal(b[i], requal_default_rsim): return false
  return true

func requal*(a: (float, float), b: (float, float), rsim: float = requal_default_rsim): bool =
  a[0].requal(b[0], requal_default_rsim) and a[1].requal(b[1], requal_default_rsim)


func `=~`*[T](a: T, b: T): bool {.inline.} = a.requal(b)
func `!~`*[T](a: T, b: T): bool {.inline.} = not(a =~ b)

test "requal":
  assert 0.0 !~ 1.0
  assert 1.0 !~ 0.0
  assert 0.0 =~ 0.0
  assert 1.0 =~ 1.0009
  assert 1.0 !~ 1.0011
  assert 1.0 !~ -1.0


func pow*(x, y: int): int = pow(x.to_float, y.to_float).to_int
proc `^`*(base: float | int, pow: float | int): float = base.pow(pow)


func quantile*(values: open_array[float], q: float, is_sorted = false): float =
  let sorted = if is_sorted: values.to_seq else: values.sorted
  let pos = (sorted.len - 1).to_float * q
  let base = pos.floor.to_int
  let rest = pos - base.to_float
  if (base + 1) < sorted.len:
    sorted[base] + rest * (sorted[base + 1] - sorted[base])
  else:
    sorted[base]

test "quantile":
  assert quantile([1.0, 2.0, 3.0], 0.5) =~ 2.0
  assert quantile([1.0, 2.0, 3.0, 4.0], 0.5) =~ 2.5
  assert quantile([1.0, 2.0, 3.0, 4.0], 0.25) =~ 1.75


type FillMissingKind* = enum jump
autoconvert FillMissingKind

proc fill_missing*[N: int | float](values: seq[Option[N]], kind: FillMissingKind = "jump"): seq[N] =
  # Fill missing values in sequence

  if not values.len > 1: throw fmt"should have at least 2 values for interpolate"
  # Allowing only internal undefined spans, begin and end should be defined
  if values[0].is_none:  throw "interpolate require first value to be defined"
  if values[^1].is_none: throw "interpolate require last value to be defined"

  # Filling missing values with the next known value.
  # rates will be sudden jumps, not linear interpolation, it makes more sense for financial prices.
  if kind == "jump":
    var filled: seq[N]
    filled.set_len values.len
    var i = values.len - 1
    while i >= 0:
      filled[i] = if values[i].is_some: values[i].get else: filled[i + 1]
      i -= 1
    filled
  else:
    throw "unsupported"

test "fill_missing":
  let u = int.none
  proc o(v: int): Option[int] = v.some

  assert @[
    o(1), u,   u,   o(2), u,   u,  o(1)
  ].fill_missing == @[
    1,    2,   2,   2,    1,   1,  1
  ]


proc rate*[N: int | float](values: seq[N], span = 1): seq[float] =
  if values.len <= span: throw fmt"should have at least {span + 1} values"
  result.set_len values.len - span
  for i in 0..<(values.len - span):
    let (a, b) = (values[i], values[i+span])
    if a <= 0.0 or b <= 0.0: throw "rates expect non negative values"
    result[i] = b / a


test "rate":
  assert @[1.0, 2.0, 2.0, 1.0].rate == @[2.0, 1.0, 0.5]

  # // Annual revenues
  # assert.equal(differentiate([
  #   //  1,     2,     3,     4,     5,     6,     7,     8,     9,    10,    11,    12
  #       u,     u,     u,     u,     u,     1,     u,     u,     u,     u,     u,     u, // 2000-06
  #       u,     u,     u,     u,     u,   1.1,     u,     u,     u,     u,     u,     u, // 2001-06
  #       u,     u,     u,     u,     u,   1.2                                            // 2002-06
  # ]).map((v) => v ? round(v, 3) : v), [
  #   //  1,     2,     3,     4,     5,     6,     7,     8,     9,    10,    11,    12
  #       u,     u,     u,     u,     u,     u, 1.008, 1.008, 1.008, 1.008, 1.008, 1.008,
  #   1.008, 1.008, 1.008, 1.008, 1.008, 1.008, 1.007, 1.007, 1.007, 1.007, 1.007, 1.007,
  #   1.007, 1.007, 1.007, 1.007, 1.007, 1.007
  # ])


proc diff*[N: int | float](values: seq[N], span = 1): seq[float] =
  if values.len <= span: throw fmt"should have at least {span + 1} values"
  result.set_len values.len - span
  for i in 0..<(values.len - span):
    result[i] = values[i+span] - values[i]

test "diff":
  assert @[1.0, 2.0, 2.0, 1.0].diff == @[1.0, 0.0, -1.0]


proc range*(a, b: float, count: int): seq[float] =
  let step = (b - a) / count.float
  result.add a
  for i in 1..<count:
    result.add result[i-1] + step
  result.add b

test "range":
  assert range(-1.0, 1.0, 4) == @[-1.0, -0.5, 0.0, 0.5, 1.0]


func sum*(values: openarray[int]): int = values.foldl(a + b, 0)

func sum*(values: openarray[float]): float = values.foldl(a + b, 0.0)

func sum*[T](values: openarray[T], op: (T) -> float): float =
  for v in values: result += op(v)


func div_rem*(x, y: float | int): (int, int) =
  (x.floor_div(y), x mod y)


func median*(values: openarray[float], is_sorted = false): float =
  quantile(values, 0.5, is_sorted)


func mean*(values: openarray[float]): float = values.sum() / values.len.to_float


func domain*(values: openarray[float]): (float, float) = (values.min, values.max)


func min_max_rate*(a: float | int, b: float | int): float =
  assert(((a >= 0 and b >= 0) or (a <= 0 and b <= 0)), fmt"different signs for min_max_rate {a} {b}")
  result = min(a.float, b.float) / max(a.float, b.float)
  assert(result >= 0 and result <= 1, "invalid rate")

func max_min_rate*(a: float | int, b: float | int): float =
  assert(((a >= 0 and b >= 0) or (a <= 0 and b <= 0)), fmt"different signs for min_max_rate {a} {b}")
  result = max(a.float, b.float) / min(a.float, b.float)
  assert(result >= 1, "invalid rate")


func is_number*(n: float): bool =
  let ntype = n.classify
  ntype == fc_normal or ntype == fc_zero or ntype == fc_neg_zero


type Point2D = tuple[x: float, y: float]
type Point3D = tuple[x: float, y: float, z: float]


func idw*(points: openarray[P2], x: float, regularize = 1e-9): float =
  # Inverse Distance Weighting
  # regularize - to prevent division by zero for sample points with the same location as query points

  # Ensuring approximated point inside of points
  let (xmin, xmax) = (points.find_min(p => p.x).x, points.find_max(p => p.x).x)
  assert(xmin <= x and x <= xmax, "approximated x lies outside of neighbours")

  let distances = points.map(p => (p.x - x).abs)
  let weights = distances.map(d => 1/(d + regularize))
  for i, w in weights:
    result += w * points[i].y
  result /= weights.sum

test "idw":
  assert @[(1.0, 2.0), (4.0, 5.0)].idw(2.0) =~ 3.0

# doc({
#   tags:  ('Math', 'Approximation'],
#   title: 'Inverse Distance Weighting',
#   text:  `
# Inverse Distance Weighted is a deterministic spatial interpolation approach to estimate an unknown value at a
# location using some known values with corresponding weighted values. It's the weighted average, the weight
# inverse proportional to the distnance between known and approximated point.

# The approximation for value $x$ for function $z(x)$ found as:

# $$z(x) : x \\rightarrow R$$
# $$z_x = {{\\sum z_i w_i} \\over \\sum w_i}$$ where
# $$w_i = distance(x, x_i)^{-1}$$

# This approach frequently used in geography to interpolate the earth surface:

# ![](math/idw.gif)
#   `
# })


proc interpolate*(efn: seq[P2], x: seq[float], skip = false): seq[P2] =
  # Interpolate empyrical fn in given x points.

  let (exmin, exmax) = (efn[0].x, efn[^1].x)
  let x = if skip: x.filter(xi => exmin <= xi and xi <= exmax) else: x

  assert exmin <= x[0],  "lower end of interpolated x is lower than available points"
  assert exmax >= x[^1], "upper end of interpolated x is higher than available points"

  var j = 0
  for xi in x:
    while true:
      if efn[j].x <= xi and efn[j+1].x >= xi: break
      j += 1

    result.add (x: xi, y: idw([efn[j], efn[j+1]], xi))

test "interpolate":
  assert @[(1.0, 2.0), (3.0, 4.0), (5.0, 6.0)].interpolate(@[2.0, 3.0]) =~ @[(2.0, 3.0), (3.0, 4.0)]
  assert @[(1.0, 2.0), (3.0, 4.0)].interpolate(@[0.0, 2.0, 3.0], true) =~ @[(2.0, 3.0), (3.0, 4.0)]


# // min_max_norm --------------------------------------------------------------------------
# export function min_max_norm(values: number[], min: number, max: number): number[] {
#   return values.map((v) => (v - min) / (max - min))
# }


# // map_with_rank -------------------------------------------------------------------------
# // Attach to every element its rank in the ordered list, ordered according to `order_by` function.
# export function map_with_rank<V, R>(list: V[], order_by: (v: V) => number, map: (v: V, rank: number) => R): R[] {
#   // Sorting accourding to rank
#   const list_with_index = list.map((v, i) => ({ v, original_i: i, order_by: order_by(v) }))
#   const sorted = sort_by(list_with_index, ({ order_by }) => order_by)

#   // Adding rank, if values returned by `order_by` are the same, the rank also the same
#   const sorted_with_rank: { v: V, original_i: number, order_by: number, rank: number }[] = []
#   let rank = 1
#   for (let i = 0; i < sorted.length; i++) {
#     const current = sorted[i]
#     if (i > 0 && current.order_by != sorted[i - 1].order_by) rank++
#     sorted_with_rank.push({ ...current, rank })
#   }

#   // Restoring original order and mapping
#   const original_with_rank = sort_by(sorted_with_rank, ({ original_i }) => original_i)
#   return original_with_rank.map(({ v, rank }) => map(v, rank))
# }
# test(() => {
#   assert.equal(
#     map_with_rank(
#       [ 4,        2,        3,        4,        5,        7,        5], (v) => v, (v, r) => [v, r]
#     ),
#     [ [ 4, 3 ], [ 2, 1 ], [ 3, 2 ], [ 4, 3 ], [ 5, 4 ], [ 7, 5 ], [ 5, 4 ] ]
#   )
# })


# // linear_regression ---------------------------------------------------------------------
# // https://stackoverflow.com/questions/6195335/linear-regression-in-javascript
# // return (a, b) that minimize
# // sum_i r_i * (a*x_i+b - y_i)^2
# //
# // Is wrong for EXPE
# function linear_regression_wrong(x_y:   [number, number][]): [number, number]
# function linear_regression_wrong(x_y_r: [number, number, number][]): [number, number]
# function linear_regression_wrong(x_y_r: [number, number, number?][]): [number, number] {
#   const xyr = x_y_r.map(([x, y, r]) => [x, y, r === undefined ? 1 : r])
#   let i,
#       x, y, r,
#       sumx=0, sumy=0, sumx2=0, sumy2=0, sumxy=0, sumr=0,
#       a, b

#   for(i=0; i<xyr.length; i++) {
#       // this is our data pair
#       x = xyr[i][0], y = xyr[i][1]

#       // this is the weight for that pair
#       // set to 1 (and simplify code accordingly, ie, sumr becomes xy.length) if weighting is not needed
#       r = xyr[i][2]

#       // consider checking for NaN in the x, y and r variables here
#       // (add a continue statement in that case)

#       sumr += r
#       sumx += r*x
#       sumx2 += r*(x*x)
#       sumy += r*y
#       sumy2 += r*(y*y)
#       sumxy += r*(x*y)
#   }

#   // note: the denominator is the variance of the random variable X
#   // the only case when it is 0 is the degenerate case X==constant
#   b = (sumy*sumx2 - sumx*sumxy)/(sumr*sumx2-sumx*sumx)
#   a = (sumr*sumxy - sumx*sumy)/(sumr*sumx2-sumx*sumx)

#   return [a, b]
# }
# export { linear_regression_wrong as linear_regression }


# // integrate -----------------------------------------------------------------------------
# // Calculating integral, gaps not allowed
# export function integrate(diffs: (number | undefined)[], base = 1): (number | undefined)[] {
#   assert(diffs[0] === undefined, `first element of diff serie should always be undefined`)
#   const values = fill<number | undefined>(diffs.length, undefined)
#   const first_defined_i = find_index(diffs, (v) => v !== undefined)
#   if (!first_defined_i) throw new Error(`the whole diffs serie is undefined`)
#   values[first_defined_i - 1] = base
#   for (let i = first_defined_i; i < diffs.length - 1; i++) {
#     const di = diffs[i]
#     if (di === undefined) break
#     const previous_v = values[i-1]
#     if (previous_v === undefined) throw new Error('internal error, there could be no undefined spans in values')
#     values[i] = previous_v * di
#   }
#   return values
# }
# test(() => {
#   const u = undefined
#   assert.equal(integrate([
#     u,   u,   2,   2,   2, 0.5, 0.5, 0.5, u
#   ]), [
#     u,   1,   2,   4,   8,   4,   2,   1, u
#   ])
# })


# // // mean_absolute_deviation ---------------------------------------------------------------
# // export function mean_absolute_deviation(values: number[]) {
# //   const m = mean(values)
# //   return mean(values.map((v) => m - v))
# // }