import base/[support, time, math, json, doc, seqm, option, table]


# Points -------------------------------------------------------------------------------------------
type PointT*  = (Time, float)
type PointsT* = seq[PointT]

type PointD*  = (TimeD, float)
type PointsD* = seq[PointD]

type PointM*  = (TimeM, float)
type PointsM* = seq[PointM]


proc init*(_: type[PointD], d: TimeD, v: float): PointD = (d, v)
proc init*(_: type[PointD], d: string, v: float): PointD = (TimeD.init(d), v)

proc init*(_: type[PointM], m: TimeM, v: float): PointM = (m, v)
proc init*(_: type[PointM], m: string, v: float): PointM = (TimeM.init(m), v)


# getters ------------------------------------------------------------------------------------------
proc time*(p: PointT): Time {.inline.} = p[0]
proc time*(p: PointD): TimeD {.inline.} = p[0]
proc time*(p: PointM): TimeM {.inline.} = p[0]
# proc day*(p: PointD): TimeD {.inline.} = p[0]
# proc month*(p: PointM): TimeM {.inline.} = p[0]
proc value*(p: PointT | PointD | PointM): float {.inline.} = p[1]


# converters ---------------------------------------------------------------------------------------
converter to_pointd*(p: ((int, int, int), float)): PointD = (TimeD.init(p[0][0], p[0][1], p[0][2]), p[1])
converter to_pointsd*(points: seq[((int, int, int), float)]): PointsD = points.map((p) => p.to_pointd)

converter to_pointm*(p: ((int, int), float)): PointM = (TimeM.init(p[0][0], p[0][1]), p[1])
converter to_pointsm*(points: seq[((int, int), float)]): PointsM = points.map((p) => p.to_pointm)


# extrapolate --------------------------------------------------------------------------------------
# Extrapolation done as calculating the slope between the last and the given point in past and
# projecting it into the future ![](normalization/cpi-extrapolation.jpg).
# Used for CPI.
todo:
  "Try linear regression, or exponential moving average maybe it would be better " &
  "plot to see current method vs linear regression, find best with backtesting?"

proc extrapolate*(
  serie:                     seq[PointM],
  months:                    int,
  past_months_to_infer_from: int
): seq[PointM] =
  # Calculating CPI monthly slope from the past data
  let b = serie[^1].value
  let a = serie[^(past_months_to_infer_from + 1)].value
  let monthly_slope  = (b - a) / past_months_to_infer_from.float

  # Projecting into future
  var extrapolated = serie
  var last = serie.last
  for i in 1..months:
    extrapolated.add((
      last.time + i.months,
      last.value + monthly_slope * i.float
    ))
  extrapolated

test "extrapolate":
  let past_rates_m: seq[PointM] = @[
    ((2000, 1), 1.0), ((2000, 2), 2.0), ((2000, 3), 3.0), ((2000, 4), 4.0), ((2000, 5), 5.0)
  ]
  assert extrapolate(past_rates_m, 2, 4) == @[
    ((2000, 1), 1.0), ((2000, 2), 2.0), ((2000, 3), 3.0), ((2000, 4), 4.0), ((2000, 5), 5.0),
    ((2000, 6), 6.0), ((2000, 7), 7.0)
  ]


# zip ----------------------------------------------------------------------------------------------
proc zip*[T](serie_a: seq[(T, float)], serie_b: seq[(T, float)]): seq[(T, float, float)] =
  var bi_start_from = 0
  for i in 0..(serie_a.len - 1):
    let (atime, avalue) = serie_a[i]
    let bi = serie_b.findi((p) => p.time == atime, bi_start_from)
    if bi >= 0:
      result.add((atime, avalue, serie_b[bi][1]))
      bi_start_from = bi + 1
    elif not result.is_empty:
      return # not allowing spans

test "zip":
  # Spans not allowed
  let a: PointsM = @[((2000, 1), 1.0), ((2000, 2), 2.0), ((2000, 3), 3.0),                   ((2000, 5), 0.1)]
  let b: PointsM = @[                  ((2000, 2), 0.3), ((2000, 3), 0.2), ((2000, 4), 0.1),                 ]
  assert zip(a, b) == @[(TimeM.init(2000, 2), 2.0, 0.3), (TimeM.init(2000, 3), 3.0, 0.2)]


# differentiate ------------------------------------------------------------------------------------
# Calculating differences for sparce values
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


# extrapolate_median -------------------------------------------------------------------------------
# # Extrapolation done as calculating the median diff and projecting it into the future.
# proc extrapolate_median*(
#   serie:                     seq[PointM],
#   months:                    int,
#   past_months_to_infer_from: int
# ): seq[PointM] =
#   # Calculating CPI monthly slope from the past data
#   let b = serie[^1].v
#   let a = serie[^(past_months_to_infer_from + 1)].v
#   let monthly_slope  = (b - a) / past_months_to_infer_from.float

#   # Projecting into future
#   var extrapolated = serie
#   var last = serie.last
#   for i in 1..months:
#     extrapolated.add((
#       last.m + i.months,
#       last.v + monthly_slope * i.float
#     ))
#   extrapolated

# test "extrapolate":
#   let past_rates_m: seq[PointM] = @[
#     ("2000-01", 1.0), ("2000-02", 2.0), ("2000-03", 3.0), ("2000-04", 4.0), ("2000-05", 5.0)
#   ].to(PointsM)
#   assert extrapolate(past_rates_m, 2, 4) == @[
#     ("2000-01", 1.0), ("2000-02", 2.0), ("2000-03", 3.0), ("2000-04", 4.0), ("2000-05", 5.0),
#     ("2000-06", 6.0), ("2000-07", 7.0)
#   ].to(PointsM)


# to_monthly ---------------------------------------------------------------------------------------
proc to_monthly*(
  points_any:        seq[PointT | PointD | PointM],
  overwrite_latest:  Option[PointM] = PointM.none,
  spans_not_allowed                 = true         # All data older than the latest span will be removed
): seq[PointM] =
  # Aggregating into months
  var months_aggregated = init_table[TimeM, seq[float]]()
  for i, (time_any, v) in points_any:
    # let (y, m, _) = yyyy_mm_dd_to_ymd yyyy_mm_dd
    let time_m = TimeM.init(time_any)
    if not (time_m in months_aggregated): months_aggregated[time_m] = @[]
    months_aggregated[time_m].add v

  # Calculating monthly medians
  var months = months_aggregated.map((list) => list.mean)

  # Overwriting latest point
  if overwrite_latest.is_some:
    let (latest_date, latest_v) = overwrite_latest.get
    months[latest_date] = latest_v

  # Converting to array
  let months_sorted = months.keys.sort
  # let smallest = yyyy_mm_to_ym months_sorted.first
  # let largest  = yyyy_mm_to_ym months_sorted.last
  let smallest = months_sorted.first
  let largest  = months_sorted.last

  var largest_missing: Option[TimeM] = TimeM.none
  var points_m: seq[PointM] = @[]
  for y in smallest.year..largest.year:
    # For the furst data point using the first available, after that always starting from
    # the first month
    let m_start = if y == smallest.year: smallest.month else: 1
    for m in m_start..12:
      if y == largest.year and m > largest.month: break
      let time_m = TimeM.init(y, m)
      if time_m in months: points_m.add (time_m, months[time_m])
      else:                largest_missing = time_m.some

  # Removing everything older than the highest missing
  if largest_missing.is_some:
    points_m = points_m.filter((point) => point[0] > largest_missing.get)
  points_m

test "to_monthly":
  let prices_d: seq[PointD] = @[
    ((1990, 1, 1), 1.0),
    ((2000, 1, 1), 1.0), ((2000, 1, 2), 3.0),
    ((2000, 2, 1), 1.0), # (2000, 2, 2), undefined),
  ]

  assert to_monthly(prices_d) == @[
    ((2000, 1), 2.0), ((2000, 2), 1.0)
  ]

  assert to_monthly(prices_d, (TimeM.init(2000, 3), 4.0).some) == @[
    ((2000, 1), 2.0), ((2000, 2), 1.0), ((2000, 3), 4.0)
  ]


# Json ---------------------------------------------------------------------------------------------
# proc to_json_hook*(point: PointT | PointD | PointM): JsonNode = (point[0], point[1]).to_json
# proc from_json_hook*(v: var PointT, json: JsonNode) =
#   v = (json.get_elems[0].json_to(Time), json.get_elems[1].get_float)
# proc from_json_hook*(v: var PointD, json: JsonNode) =
#   v = (json.get_elems[0].json_to(TimeD), json.get_elems[1].get_float)
# proc from_json_hook*(v: var PointM, json: JsonNode) =
#   v = (json.get_elems[0].json_to(TimeM), json.get_elems[1].get_float)
