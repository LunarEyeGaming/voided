---Extra utility functions related to the manipulation of vectors.
vVec2 = {}

---Returns a string representation of a `Vec2F` `vector` to be used for hash lookups.
---@param vector Vec2F
---@return string
function vVec2.fToString(vector)
  return string.format("%f,%f", vector[1], vector[2])
end

---Returns a string representation of a `Vec2I` `vector` to be used for hash lookups.
---@param vector Vec2I
---@return string
function vVec2.iToString(vector)
  return string.format("%d,%d", vector[1], vector[2])
end

---Returns a string representation of a `Vec2I` with components `x` and `y` to be used for hash lookups.
---@param x integer
---@param y integer
---@return string
function vVec2.iToString2(x, y)
  return string.format("%d,%d", x, y)
end

---Returns a `Vec2F` from a string `str`.
---@param str string
---@return Vec2F
function vVec2.fFromString(str)
  -- Extract the strings containing the entries of the stringified Vec2F (which can be positive or negative)
  local xStr, yStr = string.match(str, "(%-?%d+%.%d+),(%-?%d+%.%d+)")

  return {tonumber(xStr), tonumber(yStr)}
end

---Returns a `Vec2I` from a string `str`.
---@param str string
---@return Vec2I
function vVec2.iFromString(str)
  -- Extract the strings containing the entries of the stringified Vec2F (which can be positive or negative)
  local xStr, yStr = string.match(str, "(%-?%d+),(%-?%d+)")

  return {tonumber(xStr), tonumber(yStr)}
end

---Inserts a Vec2F `vector` into a set `set`.
---@param set table<string, boolean>
---@param vector Vec2F
function vVec2.fSetInsert(set, vector)
  local strVec = vVec2.fToString(vector)

  set[strVec] = true
end

---Returns whether or not the given `Vec2F` `vector` is in the given set (`true` if so and `nil` if not).
---@param set table<string, boolean>
---@param vector Vec2F
function vVec2.fSetContains(set, vector)
  local strVec = vVec2.fToString(vector)

  return set[strVec]
end

---Returns an angle offset by an angle between `-fuzzAngle` and `fuzzAngle`.
---@param angle number
---@param fuzzAngle number
---@return number
function vVec2.randomAngle(angle, fuzzAngle)
  return angle + math.random() * 2 * fuzzAngle - fuzzAngle
end

---Rotates an angle toward a target angle.
---
---Based on code from the turnApproach function.
---@param input number
---@param target number
---@param rate number
---@param dt number
---@return number
---@return number
function vVec2.rotateTowardTargetAngle(input, target, rate, dt)
  local angle = input

  local targetAngle = target
  local diff = util.angleDiff(angle, targetAngle)
  if diff ~= 0 then
    angle = angle + (util.toDirection(diff) * rate) * dt
    if util.angleDiff(angle, targetAngle) * diff < 0 then
      angle = targetAngle
    end
  end

  return angle, diff
end

---Rotates a vector towards a target vector.
---@param input Vec2F
---@param target Vec2F
---@param rate number
---@param dt number
---@return Vec2F
---@return number
function vVec2.rotateTowardTarget(input, target, rate, dt)
  local angle, diff = vVec2.rotateTowardTargetAngle(vec2.angle(input), vec2.angle(target), rate, dt)
  return vec2.withAngle(angle), diff
end

---Returns the projection of vector `vector` onto vector `ontoVector`.
---
---@param vector Vec2F the vector to project
---@param ontoVector Vec2F the vector onto which to project
---@return Vec2F the projection of `vector` onto `ontoVector`.
function vVec2.projection(vector, ontoVector)
  local factor = (vector[1] * ontoVector[1] + vector[2] * ontoVector[2])
  / (ontoVector[1] * ontoVector[1] + ontoVector[2] * ontoVector[2])

  return {ontoVector[1] * factor, ontoVector[2] * factor}
end