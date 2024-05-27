require "/scripts/util.lua"

-- Utility scripts created by "Void Eye Gaming."
voidedUtil = {}

-- Certain scripts may not work under specific script contexts due to some built-in tables being
-- unavailable. The legend below is intended to help in knowing when using each function is appropriate.
-- * = works under any script context
-- # = requires certain Starbound tables. See each table's documentation for more details at 
--     Starbound/doc/lua/ or https://starbounder.org/Modding:Lua/Tables

-- #statuscontroller
function voidedUtil.hasStatusEffect(statusEffect)
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
function voidedUtil.polarRect(xLength, yLength, angle)
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
function voidedUtil.strStartsWith(str, start)
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
function voidedUtil.updateCircleBar(lPart, rPart, cur, max)
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
function voidedUtil.lerpColor(ratio, colorA, colorB)
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
function voidedUtil.lerpColorRGB(ratio, colorA, colorB)
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
function voidedUtil.frameNumber(frameTime, frameCycle, startFrame, numFrames)
  return math.floor(frameTime / frameCycle * numFrames) + startFrame
end

--[[
  Returns the string hexadecimal representation of a color table, with red, green, and blue values, as well as an
  optional alpha channel.
  
  color: the color table to convert
]]
function voidedUtil.stringOfColor(color)
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
    2(1 - x) if x < 0.5
    2x if x >= 0.5
  }
  f has a range of [0, 1]
  This results in a function that rises to 1 until ratio = 0.5, where it goes back down to 0.
]]
function voidedUtil.pingPong(ratio)
  if ratio < 0.5 then
    return 2 * ratio
  else
    return 2 * (1 - ratio)
  end
end

--[[
  Requirements: #world, must be called in a coroutine

  Sends multiple entity messages of the given `messageType`, supplied with arguments, to `targets`, calling 
  `successCallback` if the corresponding promise succeeds and calling `errorCallback` otherwise.
  
  param successCallback: the function to call when a promise succeeds. Signature: successCallback(promise, id)
    promise: the promise captured
    id: the ID of the entity associated with the promise captured
  param errorCallback: the function to call when a promise fails
  param targets: the entity IDs to which to send the message
  param messageType: the type of message to send
  remaining params: the arguments to supply to the message
]]
function voidedUtil.sendEntityMessageToTargets(successCallback, errorCallback, targets, messageType, ...)
  local promiseIdAssocs = {}
  
  -- Probably unnecessary, but I have the gut feeling that the return times of each promise can vary.
  for _, target in ipairs(targets) do
    table.insert(promiseIdAssocs, {promise = voidedUtil.sendEntityMessage(target, messageType, ...), id = target})
  end
  
  for _, promiseIdAssoc in ipairs(promiseIdAssocs) do
    -- If a promise was returned...
    if promiseIdAssoc.promise then
      local promise = promiseIdAssoc.promise
      local id = promiseIdAssoc.id

      -- Wait for the promise to finish.
      while not promise:finished() do
        coroutine.yield()
      end

      if promise:succeeded() then
        successCallback(promise, id)
      else
        errorCallback(promise, id)
      end
    end
  end
end

--[[
  Requirements: #world
  
  Same as world.sendEntityMessage, except it checks if the entity exists before sending the message. This is necessary
  as sending messages to nonexistent entities is implied to cause the engine to access memory that it shouldn't be
  accessing, consequently risking some nasty bugs.
]]
function voidedUtil.sendEntityMessage(entityId, messageType, ...)
  if world.entityExists(entityId) then
    return world.sendEntityMessage(entityId, messageType, ...)
  end
end

--[[
  Obfuscates some pre-selected characters in a string `str` using list `obfuscatedChars`, where each entry in the table
  is true if the corresponding character should be replaced with the `obfuscationCharacter`. Otherwise, it is left 
  alone. Whitespace characters are not affected
  
  param str: the string to obfuscate
  param obfuscatedChars: a list of the characters to obfuscate
  param obfuscationCharacter: the replacement character for obfuscated positions
  returns: a string with some characters obfuscated.
]]
function voidedUtil.obfuscateString(str, obfuscatedChars, obfuscationCharacter)
  local newString = ""

  -- Iterate over the characters of the string.
  for i = 1, #str do
    local ch = str:sub(i, i)
    
    -- If this character should be obfuscated and the character is not a whitespace character...
    if obfuscatedChars[i] and ch ~= " " and ch ~= "\n" and ch ~= "\t" and ch ~= "\f" and ch ~= "\r" then
      -- Add it as completely invisible
      newString = newString .. obfuscationCharacter
    else  -- Otherwise...
      -- Use plain concatenation to make the character visible
      newString = newString .. ch
    end
  end
  
  return newString
end

--[[
  Obfuscates some pre-selected characters in a string `str` using list `obfuscatedChars`, where each entry in the table
  is true if the corresponding character should be replaced with the character `obfuscationCharacter`. Otherwise, it is left 
  alone. Whitespace characters are not affected.
  
  param str: the string to obfuscate
  param min_: the fractional minimum number of characters to obfuscate
  param max_: the fractional maximum number of characters to obfuscate
  param obfuscationCharacter: the replacement character for obfuscated positions
  returns: a string with some characters obfuscated.
]]
function voidedUtil.obfuscateStringMinMax(str, min_, max_, obfuscationCharacter)
  local newString = ""
  
  local obfuscatedChars = {}
  local numReplacements = math.random(math.floor(min_ * #str), math.floor(max_ * #str))
  
  -- Generate a table of numReplacements true values followed by #str - numReplacements false values. This method 
  -- ensures that the distribution for the number of replacements remains uniform and so does the location of those 
  -- replacements.
  for i = 1, #str do
    if i <= numReplacements then
      table.insert(obfuscatedChars, true)
    else
      table.insert(obfuscatedChars, false)
    end
  end
  
  -- Shuffle the list
  shuffle(obfuscatedChars)

  -- Iterate over the characters of the string.
  for i = 1, #str do
    local ch = str:sub(i, i)
    
    -- If this character should be obfuscated and the character is not a whitespace character...
    if obfuscatedChars[i] and ch ~= " " and ch ~= "\n" and ch ~= "\t" and ch ~= "\f" and ch ~= "\r" then
      -- Add it as completely invisible
      newString = newString .. obfuscationCharacter
    else  -- Otherwise...
      -- Use plain concatenation to make the character visible
      newString = newString .. ch
    end
  end
  
  return newString
end