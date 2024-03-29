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
--[[
  Updates a circular display of a stat. The circular display must have two parts.
  lPart: The left part name of the display
  rPart: The right part name of the display
  cur: Current stat value
  max: Max stat value
  Precondition: 0.0 <= cur / max <= 1.0
]]
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

-- *
--[[ 
  Returns the linear interpolation between two RGBA colors with a given ratio. Result is in integer form and capped
  between 0 and 255.
  ratio: The amount of progress in the interpolation
  colorA: Starting color
  colorB: Ending color
]]
function lerpColor(ratio, colorA, colorB)
  -- Return the linear interpolation of colorA and colorB with ratio, capped between 0 and 255 and in integer form.
  return {
    math.floor(math.max(math.min(colorA[1] + (colorB[1] - colorA[1]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[2] + (colorB[2] - colorA[2]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[3] + (colorB[3] - colorA[3]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[4] + (colorB[4] - colorA[4]) * ratio, 255), 0))
  }
end

-- *
--[[ 
  Returns the linear interpolation between two RGB colors with a given ratio. Result is in integer form and capped
  between 0 and 255.
  ratio: The amount of progress in the interpolation
  colorA: Starting color
  colorB: Ending color
]]
function lerpColorRGB(ratio, colorA, colorB)
  -- Return the linear interpolation of colorA and colorB with ratio, capped between 0 and 255 and in integer form.
  return {
    math.floor(math.max(math.min(colorA[1] + (colorB[1] - colorA[1]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[2] + (colorB[2] - colorA[2]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[3] + (colorB[3] - colorA[3]) * ratio, 255), 0))
  }
end

-- *
--[[
  Returns the frame number corresponding to a given time, provided a frameCycle, numFrames, and a startFrame.
  
  frameTime: the time elapsed since the last frame cycle
  frameCycle: the amount of time it takes to complete one full cycle
  startFrame: the number at which the frames start
  numFrames: the number of frames in a cycle
  
  precondition: 0 <= frameTime <= frameCycle
]]
function frameNumber(frameTime, frameCycle, startFrame, numFrames)
  return math.floor(frameTime / frameCycle * numFrames) + startFrame
end

--[[
  Returns the string hexadecimal representation of a color table, with red, green, and blue values, as well as an
  optional alpha channel.
  
  color: the color table to convert
]]
function stringOfColor(color)
  local rChannel = color[1]  -- red
  local gChannel = color[2]  -- green
  local bChannel = color[3]  -- blue
  local aChannel = color[4]  -- alpha
  
  -- Initial string
  local str = string.format("%02x%02x%02x", rChannel, gChannel, bChannel)
  
  -- If an alpha channel is provided, add it.
  if aChannel then
    str = string.format("%s%02x", str, aChannel)
  end
  
  return str
end

--[[
  Takes in a ratio (a value between 0 and 1) and maps it to the following piecewise function: f(x) = {
    2x if x < 0.5
    2(1 - x) if x >= 0.5
  }
  f has a range of [0, 1]
  This results in a function that rises to 1 until ratio = 0.5, where it goes back down to 0.
]]
function pingPong(ratio)
  if ratio < 0.5 then
    return 2 * ratio
  else
    return 2 * (1 - ratio)
  end
end