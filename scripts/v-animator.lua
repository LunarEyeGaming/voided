require "/scripts/util.lua"

vAnimator = {}

-- Camera can pan 600 px, or 75 blocks at 1x zoom. Will need double this value to ensure full coverage of viewing
-- range.
vAnimator.WINDOW_PADDING = 150

--- Updates a circular display of a stat. The circular display must have two parts.
---
--- Requires: `animator`
---
--- @param lPart string: The left part name of the display
--- @param rPart string: The right part name of the display
--- @param cur number: Current stat value
--- @param max number: Max stat value
--- @precondition 0.0 <= cur / max <= 1.0
function vAnimator.updateCircleBar(lPart, rPart, cur, max)
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

---Returns the linear interpolation between two RGBA colors with a given ratio. Result is in integer form and capped
---between 0 and 255.
---
---Requires: None
---@param ratio number The amount of progress in the interpolation
---@param colorA ColorTable Starting color
---@param colorB ColorTable Ending color
---@return ColorTable
function vAnimator.lerpColor(ratio, colorA, colorB)
  -- Return the linear interpolation of colorA and colorB with ratio, capped between 0 and 255 and in integer form.
  return {
    math.floor(math.max(math.min(colorA[1] + (colorB[1] - colorA[1]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[2] + (colorB[2] - colorA[2]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[3] + (colorB[3] - colorA[3]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[4] + (colorB[4] - colorA[4]) * ratio, 255), 0))
  }
end

---Returns the linear interpolation between two RGB colors with a given ratio. Result is in integer form and capped
---between 0 and 255.
---
---Requires: None
---@param ratio number The amount of progress in the interpolation
---@param colorA ColorTable Starting color
---@param colorB ColorTable Ending color
---@return ColorTable
function vAnimator.lerpColorRGB(ratio, colorA, colorB)
  -- Return the linear interpolation of colorA and colorB with ratio, capped between 0 and 255 and in integer form.
  return {
    math.floor(math.max(math.min(colorA[1] + (colorB[1] - colorA[1]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[2] + (colorB[2] - colorA[2]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[3] + (colorB[3] - colorA[3]) * ratio, 255), 0))
  }
end


---Returns the string hexadecimal representation of a color table, with red, green, and blue values, as well as an
---optional alpha channel.
---
---Requires: None
---@param color ColorTable
---@return string
function vAnimator.stringOfColor(color)
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

---Returns a color table containing the red, green, and blue channels represented by the hexadecimal color `str`. If the
---alpha channel is defined, that is also included in the table. If `str` is too short, `nil` is returned instead.
---
---Requires: None
---@param str string
---@return ColorTable|nil
function vAnimator.colorOfString(str)
  local result

  -- If the string is long enough to contain the red, green, and blue channels...
  if #str >= 6 then
    -- Convert each color component into a number. Alpha channel is nil if the string is not long enough.
    result = {
      tonumber(str:sub(1, 2), 16),
      tonumber(str:sub(3, 4), 16),
      tonumber(str:sub(5, 6), 16),
      #str == 8 and tonumber(str:sub(7, 8), 16) or nil
    }
  else
    result = nil
  end

  return result
end

-- TODO: Maybe rework this into an Animator class (and rename vAnimator to vAnimation to avoid confusion)

---Returns the frame number corresponding to a given time, provided a `frameCycle`, `numFrames`, and a `startFrame`.
---
---precondition: `0 <= frameTime <= frameCycle`
---@param frameTime number the time elapsed since the last frame cycle
---@param frameCycle number the amount of time it takes to complete one full cycle
---@param startFrame integer the number at which the frames start
---@param numFrames integer the number of frames in a cycle
---@return number
function vAnimator.frameNumber(frameTime, frameCycle, startFrame, numFrames)
  return math.floor(frameTime / frameCycle * numFrames) + startFrame
end