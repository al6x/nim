import ./supportm, ./algorithm, std/math, sequtils, strformat, sugar

export math


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

func `=~`*(a: float, b: float): bool {.inline.} = a.requal(b)
func `!~`*(a: float, b: float): bool {.inline.} = not(a =~ b)

test "requal":
  assert 0.0 !~ 1.0
  assert 1.0 !~ 0.0
  assert 0.0 =~ 0.0
  assert 1.0 =~ 1.0009
  assert 1.0 !~ 1.0011
  assert 1.0 !~ -1.0


# pow ----------------------------------------------------------------------------------------------
func pow*(x, y: int): int = pow(x.to_float, y.to_float).to_int
proc `^`*(base: float | int, pow: float | int): float = base.pow(pow)


# quantile -----------------------------------------------------------------------------------------
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


# sum ----------------------------------------------------------------------------------------------
func sum*(values: openarray[int]): int = values.foldl(a + b, 0)

func sum*(values: openarray[float]): float = values.foldl(a + b, 0.0)

func sum*[T](values: openarray[T], op: (T) -> float): float =
  for v in values: result += op(v)


# div_rem ------------------------------------------------------------------------------------------
func div_rem*(x, y: float | int): (int, int) =
  (x.floor_div(y), x mod y)


# median -------------------------------------------------------------------------------------------
func median*(values: openarray[float], is_sorted = false): float =
  quantile(values, 0.5, is_sorted)


# mean ---------------------------------------------------------------------------------------------
func mean*(values: openarray[float]): float = values.sum() / values.len.to_float


# min_max_rate -------------------------------------------------------------------------------------
func min_max_rate*(a: float | int, b: float | int): float =
  assert(((a >= 0 and b >= 0) or (a <= 0 and b <= 0)), fmt"different signs for min_max_rate {a} {b}")
  result = min(a.float, b.float) / max(a.float, b.float)
  assert(result >= 0 and result <= 1, "invalid rate")


# is_number ----------------------------------------------------------------------------------------
func is_number*(n: float): bool =
  let ntype = n.classify
  ntype == fc_normal or ntype == fc_zero or ntype == fc_neg_zero


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