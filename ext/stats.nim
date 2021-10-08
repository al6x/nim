import base, ./gsl


type CRand* = object
  state*: ptr gsl_rng

proc `=destroy`*(self: var CRand) =
    self.state.gsl_rng_free

with CRand:
  proc init*(tself; seed = 0): CRand =
    gsl_rng_default_seed = seed.uint
    CRand(state: gsl_rng_alloc(gsl_rng_default))

  proc rand*(self: var CRand): float =
    self.state.gsl_rng_uniform

var default_crgen* = CRand.init


proc crand*(max: Natural, rgen: var CRand = default_crgen): int =
  gsl_rng_uniform_int(rgen.state, (max + 1).culong).int

proc crand*(max: float, rgen: var CRand = default_crgen): float =
  max * rgen.rand()

proc crand*(_: type[bool], rgen: var CRand = default_Crgen): bool =
  1.rand(rgen) > 0

proc crand*[V](list: openarray[V], rgen: var CRand = default_crgen): V =
  list[(list.len - 1).rand(rgen)]


type Normal* = object
  mu*:    float
  sigma*: float

proc normal_cdf*(mu, sigma, x: float): float =
  gsl_cdf_gaussian_P(x - mu, sigma)

proc normal_rand*(mu, sigma: float, rgen: var CRand = default_crgen): float =
  mu + gsl_ran_gaussian(rgen.state, sigma)

with Normal:
  proc fit*(tself; sample: seq[float], a, b: int): Normal =
    let len = b - a + 1
    # let mu = sample.sum / sample.len.float
    var mu = 0.0
    for i in a..b: mu += sample[i]
    mu /= len.float

    # let sigma = (sample.map(v => (v - mu)^2.0).sum / sample.len.float)^0.5
    var sigma = 0.0
    for i in a..b: sigma += (sample[i] - mu)^2.0
    sigma = (sigma / len.float)^0.5
    Normal(mu: mu, sigma: sigma)

  proc fit*(tself; sample: seq[float]): Normal =
    tself.fit(sample, 0, sample.len - 1)

  proc cdf*(self; x: float): float =
    normal_cdf(self.mu, self.sigma, x)

  proc rand*(self; rgen: var CRand = default_crgen): float =
    normal_rand(self.mu, self.sigma, rgen)

test "Normal":
  let n = Normal(mu: 1.0, sigma: 1.0)
  assert n.cdf(1.0) =~ 0.5


proc sample*[D](distr: D, count: int, rgen: var CRand = default_crgen): seq[float] =
  for _ in 1..count:
    result.add distr.rand(rgen)

proc cdf*(values: seq[float], normalize = true, inversed = false): seq[P2] =
  # inversed - calculates X >= x instead of X <= x
  if values.len == 0: throw "CDF requires non empty list"
  var sorted = values.sort
  if inversed: sorted = sorted.reverse

  var cdf = @[(x: sorted[0], y: 1.0)]
  for i in 1..<sorted.len:
    let previous = cdf[^1]; let x = sorted[i]
    if previous.x == x:
      cdf[^1].y += 1
    else:
      cdf.add (x, previous.y + 1)

  if normalize:
    let total = values.len.float
    for i in 0..<cdf.len: cdf[i].y = cdf[i].y / total
  if inversed: cdf = cdf.reverse
  cdf

proc qdf*(values: seq[float], normalize = true): seq[P2] =
  cdf(values, normalize = normalize, inversed = true)

test "cdf":
  assert:
    @[0.3, 0.5, 0.5, 0.8, 0.3].cdf(normalize = false) ==
    @[(0.3, 2.0), (0.5, 4.0), (0.8, 5.0)]

  assert:
    @[1.0/0.3, 1.0/0.5, 1.0/0.5, 1.0/0.8, 1.0/0.3].qdf(normalize = false) ==
    @[(1.0/0.8, 5.0), (1.0/0.5, 4.0), (1.0/0.3, 2.0)]


proc cdf_to_qdf*(cdf: seq[P2], discrete: bool): seq[P2] =
  # For discrete case, because of the equality in <= inequality, the count of the same elements
  # should be taken into account
  assert cdf.first.y <= cdf.last.y
  let total = cdf.last.y
  if discrete:
    cdf.map proc (p, i: auto): auto =
      # Using probability from the previous element to account for equality
      let y = if i == 0: 0.0 else: cdf[i-1].y
      (p.x, total - y)
  else:
    cdf.map(p => (p.x, total - p.y))

proc qdf_to_cdf*(qdf: seq[P2], discrete: bool): seq[P2] =
  # For discrete case, because of the equality in >= inequality, the count of the same elements
  # should be taken into account
  assert qdf.first.y >= qdf.last.y
  let total = qdf.first.y
  if discrete:
    let last_i = qdf.len - 1
    qdf.map proc (p, i: auto): auto =
      # Using probability from the next element to account for equality
      let y = if i < last_i: qdf[i+1].y else: 0.0
      (p.x, total - y)
  else:
    qdf.map(p => (p.x, total - p.y))

test "cdf_to_qdf":
  let sample = @[-1.0, -1.0, 0.0, 1.0]
  let cdf = sample.cdf(normalize = false)
  assert cdf == @[(-1.0, 2.0), (0.0, 3.0), (1.0, 4.0)]
  let qdf = cdf.cdf_to_qdf(true)
  assert qdf == @[(-1.0, 4.0), (0.0, 2.0), (1.0, 1.0)]
  assert qdf.qdf_to_cdf(true) == cdf


proc inv(monotonefn: ((float) -> float); y, delta: float, xrange_hint = (-1.0, 1.0)): float =
  # Inverse monotone function, fn(x) -> y => inv(y) -> x
  var (a, b) = xrange_hint
  assert a < b
  var step = b - a

  # Ensuring correct range
  while monotonefn(a) > y:
    step *= 2
    a -= step
  while monotonefn(b) < y:
    step *= 2
    b += step

  # Narrowing range
  while true:
    let xi = (b + a) / 2.0
    let yi = monotonefn(xi)
    if   yi < y - delta: a = xi
    elif yi > y + delta: b = xi
    else:                return xi

test "inv":
  proc fn(x: float): float = x
  assert inv(fn, y = 2.0, delta = 0.01) =~ 2.0


proc cdf_to_hist*(cdf: (float) -> float, intervals: openarray[float], small = 0.0001): seq[P2] =
  # The `x` are intervals, for each interval an average x used
  assert cdf(intervals[0]) <= small,          "pdf x scale misses left tail"
  assert (1.0 - cdf(intervals[^1])) <= small, "pdf x scale misses right tail"
  var xa = intervals[0]; var pa = cdf(xa)
  for b in 1..<intervals.len:
    let xb = intervals[b]
    let pb = cdf(xb)
    assert pa <= pb, "cdf should be monotone"
    assert pb <= 1.0, "cdf can't be greather than 1"
    result.add (xa + (xb - xa)/2.0, pb - pa)
    xa = xb; pa = pb
  let totalp = result.sum(d => d.y)
  assert 0.99 < totalp and totalp < 1.01, "histogram should sum up to 1"
  assert result.count(d => d.y > small).float > result.len / 3, "too much empty space in histogram"

proc cdf_to_hist*(cdf: (float) -> float, n: int, small = 0.0001): seq[P2] =
  # TODO Shift hist a little left and right to find better fit, use Anderson Darling to mesure fit
  let a = inv(cdf, small, delta = small / 2.0)
  let b = inv(cdf, 1.0 - small, delta = small / 2.0)
  let margin = 0.1 * (b - a) # Making range a little bit wider
  cdf_to_hist(cdf, intervals = range(a - margin, b + margin, n + 1), small = small)

test "cdf_to_hist":
  let uniform = proc (x: float): float =
    if x < 0: 0.0 elif x <= 1: x else: 1.0

  block:
    let hist = cdf_to_hist(uniform, [-0.5, 0.0, 0.5, 1.0, 1.5])
    assert hist == @[(-0.25, 0.0), (0.25, 0.5), (0.75, 0.5), (1.25, 0.0)]

  block:
    let hist = cdf_to_hist(uniform, 4)
    check hist[0].x  =~ 0.0201
    check hist[^1].x =~ 0.9798












# proc pqf*(values: seq[float], normalize = true): seq[P2] =
#   # P(X <= x, x < 0) and Q(X >= x, x > 0)
#   var lt1: seq[float]; var gt1: seq[float]
#   for v in values:
#     if v < 0.0: lt1.add v
#     if v > 0.0: gt1.add v

#   var pqf: seq[P2]
#   if lt1.len > 0: pqf.add cdf(lt1, normalize = false)
#   if gt1.len > 0: pqf.add cdf(gt1, normalize = false, inversed = true)

#   if normalize:
#     let total = values.len.float
#     for i in 0..<pqf.len: pqf[i].y = pqf[i].y / total
#   pqf

# test "pqf":
#   assert @[
#     -1.0, -2.0, -2.0, -3.0, -1.0,
#      1.0,  2.0,  2.0,  3.0,  1.0
#   ].pqf(normalize = false) == @[
#     (-3.0, 1.0), (-2.0, 3.0), (-1.0, 5.0),
#     ( 1.0, 5.0), ( 2.0, 3.0), ( 3.0, 1.0)
#   ]

# proc pqf*[D](dist: D, x: seq[float]): seq[P2] =
#   # P(X <= x, x < 0) and Q(X >= x, x > 0)
#   # Note that only analytical CDF could be converted to SCDF, for empirical CDF the error could
#   # be too large, because of <= and not < inequality in P(X <= x)
#   for xi in x:
#     if   xi < 0: result.add (x: xi, p: dist.cdf(xi))
#     elif xi > 0: result.add (x: xi, p: 1 - dist.cdf(xi))



# proc fit_normal_mu*(sample: seq[float], a, b: int): float =
#     let len = b - a + 1
#     for i in a..b: result += sample[i]
#     result /= len.float

# proc fit_normal_sigma*(mu: float, sample: seq[float], a, b: int): float =
#     let len = b - a + 1
#     for i in a..b: result += (sample[i] - mu)^2.0
#     result = (result / len.float)^0.5



# proc to_scdf*(cdf: seq[tuple[x: float, p: float]]): seq[tuple[x: float, p: float]] =
#   # Symmetrical CDF, same as CDF for x < 1 and 1-CDF for x > 1
#   #
#   # Altering CDF a little bit, otherwise the last CDF value with p = 1 would
#   # have SCDF p = 1 - 1 = 0
#   let alter = 0.999
#   cdf.map proc (d: auto): auto =
#     let p = if d.x <= 1: alter * d.p else: 1 - alter * d.p
#     (x: d.x, p: p)


# proc scdf1*(values: seq[float], normalize = -1): seq[tuple[x: float, p: float]] =
#   # Symmetrical CDF around 1, used for multiplicative processes, same as CDF for x < 1 and 1-CDF for x > 1
#   var lt1: seq[float]; var gt1: seq[float]
#   for v in values:
#     if v < 1.0: lt1.add v
#     if v > 1.0: gt1.add v
#   let normalize = if normalize == -1: values.len else: normalize
#   if lt1.len > 0: result.add cdf(lt1, normalize = normalize)
#   if gt1.len > 0: result.add cdf(gt1, normalize = normalize, inversed = true)

# test "scdf1":
#   assert @[
#         0.3,     0.5,     0.5,     0.8,     0.3,
#     1.0/0.3, 1.0/0.5, 1.0/0.5, 1.0/0.8, 1.0/0.3
#   ].scdf(normalize = 1) == @[
#     (    0.3, 2.0), (0.5,     4.0), (0.8,     5.0),
#     (1.0/0.8, 5.0), (1.0/0.5, 4.0), (1.0/0.3, 2.0)
#   ]


# proc cdf*(values: seq[float], normalize = values.len, inversed = false): CDF =
#   # inversed - calculates X > x instead of X < x
#   if values.len == 0: throw "CDF requires non empty list"
#   var sorted = values.sorted
#   if inversed: sorted.reverse

#   var cdf = @[(x: sorted[0], p: 1.0)]
#   for i in 1..<sorted.len:
#     let previous = cdf[^1]; let x = sorted[i]
#     if previous.x == x:
#       cdf[^1].p += 1
#     else:
#       cdf.add (x, previous.p + 1)

#   for i in 0..<cdf.len:
#     cdf[i].p = cdf[i].p / normalize.float
#   if inversed: cdf.sort
#   cdf


# proc mean_pqf*(values: seq[float], normalize = true): seq[P2] =
#   # P(X <= x, x < mean) and Q(X >= x, x > mean)
#   var lt1: seq[float]; var gt1: seq[float]
#   let middle = values.mean
#   for v in values:
#     if v < middle: lt1.add v
#     if v > middle: gt1.add v

#   var pqf: seq[P2]
#   if lt1.len > 0: pqf.add cdf(lt1, normalize = false)
#   if gt1.len > 0: pqf.add cdf(gt1, normalize = false, inversed = true)

#   if normalize:
#     let total = values.len.float
#     for i in 0..<pqf.len: pqf[i].y = pqf[i].y / total
#   pqf