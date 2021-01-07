import basem, timem, mathm, jsonm, docm


# Points -------------------------------------------------------------------------------------------
type PointT*  = tuple[t: Time, v:float]
type PointsT* = seq[PointT]

type PointD*  = tuple[d: TimeD, v:float]
type PointsD* = seq[PointD]

type PointM*  = tuple[m: TimeM, v:float]
type PointsM* = seq[PointM]


proc init*(_: type[PointD], point: (string, float)): PointD = (TimeD.init(point[0]), point[1])
proc init*(_: type[PointsD], list: seq[(string, float)]): PointsD = list.map((p) => p.to(PointD))

proc init*(_: type[PointM], point: (string, float)): PointM = (TimeM.init(point[0]), point[1])
proc init*(_: type[PointsM], list: seq[(string, float)]): PointsM = list.map((p) => p.to(PointM))

# proc to_point_d*(p: (string, float)): PointD = (TimeD.init(p[0]), p[1])
# proc to_points_d*(list: seq[(string, float)]): seq[PointD] = list.map((p) => p.to_point_d)

# proc to_point_m*(p: (string, float)): PointM = (TimeM.init(p[0]), p[1])
# proc to_points_m*(list: seq[(string, float)]): seq[PointM] = list.map((p) => p.to_point_m)


# Json ---------------------------------------------------------------------------------------------
proc `%`*(point: PointT | PointD | PointM): JsonNode = %[%(point[0]), %(point[1])]
proc init_from_json*(dst: var PointT, json: JsonNode, json_path: string) =
  dst = (json.get_elems[0].to(Time), json.get_elems[1].get_float)
proc init_from_json*(dst: var PointD, json: JsonNode, json_path: string) =
  dst = (json.get_elems[0].to(TimeD), json.get_elems[1].get_float)
proc init_from_json*(dst: var PointM, json: JsonNode, json_path: string) =
  dst = (json.get_elems[0].to(TimeM), json.get_elems[1].get_float)


# extrapolate --------------------------------------------------------------------------------------
# Extrapolation done as calculating the slope between the last and the given point in past and
# projecting it into the future ![](normalization/cpi-extrapolation.jpg).
# Used for CPI.
todo "Try linear regression, maybe it would be better, plot to see current method vs linear regression?"
proc extrapolate*(
  serie:                     seq[PointM],
  months:                    int,
  past_months_to_infer_from: int
): seq[PointM] =
  # Calculating CPI monthly slope from the past data
  let b = serie[^1].v
  let a = serie[^(past_months_to_infer_from + 1)].v
  let monthly_slope  = (b - a) / past_months_to_infer_from.float

  # Projecting into future
  var extrapolated = serie
  var last = serie.last
  for i in 1..months:
    extrapolated.add((
      last.m + i.months,
      last.v + monthly_slope * i.float
    ))
  extrapolated

test "extrapolate":
  let past_rates_m: seq[PointM] = @[
    ("2000-01", 1.0), ("2000-02", 2.0), ("2000-03", 3.0), ("2000-04", 4.0), ("2000-05", 5.0)
  ].to(PointsM)
  assert extrapolate(past_rates_m, 2, 4) == @[
    ("2000-01", 1.0), ("2000-02", 2.0), ("2000-03", 3.0), ("2000-04", 4.0), ("2000-05", 5.0),
    ("2000-06", 6.0), ("2000-07", 7.0)
  ].to(PointsM)


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
    let time_m = time_any.to(TimeM)
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
  let prices_d = @[
    ("1990-01-01", 1.0),
    ("2000-01-01", 1.0), ("2000-01-02", 3.0),
    ("2000-02-01", 1.0), # ("2000-02-02", undefined),
  ].to(PointsD)

  assert:
    to_monthly(prices_d) ==
    @[("2000-01", 2.0), ("2000-02", 1.0)].to(PointsM)

  assert:
    to_monthly(prices_d, (TimeM.init(2000, 3), 4.0).some) ==
    @[("2000-01", 2.0), ("2000-02", 1.0), ("2000-03", 4.0)].to(PointsM)