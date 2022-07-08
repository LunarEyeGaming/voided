require "/scripts/util.lua"

-- Utility scripts created by "Void Eye Gaming."

-- Certain scripts may not work under specific script contexts due to some built-in tables being
-- unavailable. The legend below is intended to help in knowing when using each function is appropriate.
-- * = works under any script context
-- # = requires certain Starbound tables. See each table's documentation for more details at 
--     Starbound/doc/lua/ or https://starbounder.org/Modding:Lua/Tables

-- #statuscontroller
function hasStatusEffect(statusEffect)
  -- Return whether or not the parent entity has the specified status effect.
  statusEffects = status.activeUniqueStatusEffectSummary()
  for _, effect in pairs(statusEffects) do
    if effect[1] == statusEffect then
      return true
    end
  end
  return false
end

-- Note: This function may or may not be broken
-- *
function polarRect(xLength, yLength, angle)
  -- A piecewise function that finds where a ray of angle <angle> from the x-axis (in radians) intersects
  -- with a rectangle of horizontal length <xLength> and vertical length <yLength> centered at the origin.
  local halfXLength = xLength / 2
  local halfYLength = yLength / 2
  local modAngle = util.wrapAngle(angle)  -- For ease of comparison
  local boundAngle = math.atan(halfYLength / halfXLength)
  -- sb.logInfo("boundAngle: %s", boundAngle)
  -- sb.logInfo("Comparison: %s < %s < %s", 2 * math.pi - boundAngle, modAngle, boundAngle)
  -- sb.logInfo("Comparison: %s < %s < %s", boundAngle, modAngle, math.pi - boundAngle)
  -- sb.logInfo("Comparison: %s < %s < %s", math.pi - boundAngle, modAngle, boundAngle + math.pi)
  -- sb.logInfo("Comparison: %s < %s < %s", boundAngle + math.pi, modAngle, 2 * math.pi - boundAngle)
  if -boundAngle < modAngle and modAngle < boundAngle then
    return {xLength, xLength * math.tan(modAngle)}
  elseif boundAngle < modAngle and modAngle < math.pi - boundAngle then
    return {yLength / math.tan(modAngle), yLength}
  elseif math.pi - boundAngle < modAngle and modAngle < boundAngle + math.pi then
    return {-xLength, -xLength * math.tan(modAngle)}
  elseif boundAngle + math.pi < modAngle and modAngle < 2 * math.pi - boundAngle then
    return {-yLength / math.tan(modAngle), yLength}
  else
    error("Could not resolve output for angle " .. angle)
  end
end

-- *
-- Not really by Void Eye Gaming
function strStartsWith(str, start)
  return str:sub(1, #start) == start
end

-- #animator
-- Update a circular display of a stat.
-- Precondition: 0.0 <= cur / max <= 1.0
function updateCircleBar(lPart, rPart, cur, max)
  local progress = cur / max
  animator.resetTransformationGroup(lPart)
  animator.resetTransformationGroup(rPart)

  if progress < 0.5 then
    animator.setAnimationState(rPart, "invisible")
    animator.rotateTransformationGroup(lPart, util.lerp((0.5 - progress) * 2, 0, -math.pi))
  else
    animator.setAnimationState(rPart, "visible")
    animator.rotateTransformationGroup(rPart, util.lerp((0.5 - (progress - 0.5)) * 2, 0, -math.pi))
  end
end