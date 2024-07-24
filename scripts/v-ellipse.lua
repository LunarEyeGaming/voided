vEllipse = {}

---For a given `period` and time `t`, calculates and returns the corresponding position on an ellipse with a
---vector-based `radius` centered at `center`.
---
---When `t` = `period`, the position will be the same as when `t` = 0, and the points progress in a counterclockwise
---order.
---@param center Vec2F the position at which the ellipse is centered
---@param radius Vec2F a vector signifying the radius of the ellipse at the horizontal and vertical axes respectively
---@param period number the amount of "time" it takes to complete one revolution around the center point along the
---ellipse
---@param t number the amount of "time" that has elapsed.
---@param offset? number an offset angle to add to the initially calculated angle.
function vEllipse.point(center, radius, period, t, offset)
  local angle = t / period * 2 * math.pi + (offset or 0)
  return {center[1] + radius[1] * math.cos(angle), center[2] + radius[2] * math.sin(angle)}
end

---Debug-displays in the world an ellipse with center `center`, vector radius `radius`, `numPoints` points, and a color
---`color`.
---@param center Vec2F
---@param radius Vec2F
---@param numPoints integer
---@param color string
function vEllipse.debug(center, radius, numPoints, color)
  local points = {}
  for i = 1, numPoints do
    table.insert(points, vEllipse.point(center, radius, numPoints, i))
  end

  world.debugPoly(points, color)
end