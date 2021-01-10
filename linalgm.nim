import system except find
import basem, mathm

type Point2D = tuple[x: float, y: float]
type Point3D = tuple[x: float, y: float, z: float]

# inverse_distance_weighting -----------------------------------------------------------------------
func inverse_distance_weighting*(points: seq[Point3D], target: Point2D): float =
  let (x, y) = target

  # Ensuring approximated point inside of points
  let xis = points.map((p) => p.x)
  let yis = points.map((p) => p.y)
  assert((xis.min <= x) and (x <= xis.max), "x of approximated point lies outside of neighbours")
  assert((yis.min <= y) and (y <= yis.max), "y of approximated point lies outside of neighbours")

  # Calculating distances
  let distances = points.map((p) => ((p.x - x).pow(2) + (p.y - y).pow(2)).sqrt)

  # Handling special case when distance is 0
  let minimal_distance = 1000.0 * float.low
  let very_close_point_i = distances.findi((d) => d < minimal_distance)
  if very_close_point_i.is_some: return points[very_close_point_i.get].z

  # Calculating weights
  let weights = distances.map((d) => 1/d)

  # Calculating weighted sum
  return weights.map((w, i) => w * points[i].z).sum / weights.sum

test "inverse_distance_weighting":
  assert inverse_distance_weighting(
    @[(3.0, 3.0, 1.0), (5.0, 3.0, 2.0), (5.0, 5.0, 2.0), (3.0, 5.0, 1.0)], (4.0, 4.0)) =~ 1.5
  assert inverse_distance_weighting(
    @[(3.0, 3.0, 1.0), (5.0, 3.0, 2.0), (5.0, 5.0, 2.0), (3.0, 5.0, 1.0)], (4.5, 4.5)) =~ 1.6496
  assert inverse_distance_weighting(
    @[(3.0, 3.0, 1.0), (3.0, 3.0, 1.0), (3.0, 3.0, 1.0), (3.0, 3.0, 1.0)], (3.0, 3.0)) =~ 1.0


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