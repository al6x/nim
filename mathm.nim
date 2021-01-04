import supportm, algorithm, std/math, sequtils

export math

# quantile -------------------------------------------------------------------------------
proc pow*(x, y: int): int = pow(x.to_float, y.to_float).to_int

# quantile -------------------------------------------------------------------------------
proc quantile*(values: open_array[float], q: float, is_sorted = false): float =
  let sorted = if is_sorted: values.to_seq else: values.sorted
  let pos = (sorted.len - 1).to_float * q
  let base = pos.floor.to_int
  let rest = pos - base.to_float
  if (base + 1) < sorted.len:
    sorted[base] + rest * (sorted[base + 1] - sorted[base])
  else:
    sorted[base]

test "quantile":
  assert quantile(@[1.0, 2.0, 3.0], 0.5) == 2.0
  assert quantile(@[1.0, 2.0, 3.0, 4.0], 0.5) == 2.5


# sum ----------------------------------------------------------------------------------------------
proc sum*(values: openarray[float]): float = values.foldl(a + b, 0.0)


# median -------------------------------------------------------------------------------------------
proc median*(values: openarray[float], is_sorted = false): float =
  quantile(values, 0.5, is_sorted)


# mean ---------------------------------------------------------------------------------------------
proc mean*(values: openarray[float]): float = values.sum() / values.len.to_float


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


# // differentiate -------------------------------------------------------------------------
# // Calculating differences for sparce values
# export function differentiate(sparce_values: (number | undefined)[]): (number | undefined)[] {
#   const diffs = fill<number | undefined>(sparce_values.length, undefined)

#   // Converting sparce values to list of defined values and its indices
#   const values = filter_map(sparce_values, (v, i) => v !== undefined ? [i, v] : false)

#   let index_consistency_check = values[0][0]
#   for (let j = 0; j < values.length - 1; j++) {
#     const [i1, v1] = values[j], [i2, v2] = values[j + 1]

#     // Calculating the diff for the whole `i1-i2` span and diff for every i
#     const span_diff = v2 / v1
#     if (span_diff <= 0) throw new Error(`differentiate expect positive values`)
#     const diff_i    = Math.pow(span_diff, 1/(i2 - i1))

#     for (let i = i1; i < i2; i++) {
#       assert.equal(index_consistency_check, i)
#       diffs[i + 1] = diff_i
#       index_consistency_check += 1
#     }
#   }

#   assert(diffs[0] === undefined, `first element of diff serie should always be undefined`)
#   return diffs
# }
# test(() => {
#   const u = undefined
#   assert.equal(differentiate([
#     u,   1,   u,   u,   8,   u,   u,   1, u
#   ]), [
#     u,   u,   2,   2,   2, 0.5, 0.5, 0.5, u
#   ])

#   assert.equal(differentiate([
#     u,   1,   u,   u,   8
#   ]), [
#     u,   u,   2,   2,   2
#   ])

#   // Annual revenues
#   assert.equal(differentiate([
#     //  1,     2,     3,     4,     5,     6,     7,     8,     9,    10,    11,    12
#         u,     u,     u,     u,     u,     1,     u,     u,     u,     u,     u,     u, // 2000-06
#         u,     u,     u,     u,     u,   1.1,     u,     u,     u,     u,     u,     u, // 2001-06
#         u,     u,     u,     u,     u,   1.2                                            // 2002-06
#   ]).map((v) => v ? round(v, 3) : v), [
#     //  1,     2,     3,     4,     5,     6,     7,     8,     9,    10,    11,    12
#         u,     u,     u,     u,     u,     u, 1.008, 1.008, 1.008, 1.008, 1.008, 1.008,
#     1.008, 1.008, 1.008, 1.008, 1.008, 1.008, 1.007, 1.007, 1.007, 1.007, 1.007, 1.007,
#     1.007, 1.007, 1.007, 1.007, 1.007, 1.007
#   ])

#   // Should check for negative values
#   let error_message = undefined
#   try { differentiate([u,  1, u, -1]) }
#   catch (e) { error_message = e.message }
#   assert.equal(error_message, `differentiate expect positive values`)
# })


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