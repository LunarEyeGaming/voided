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
  Obfuscates between `min_` and `max_` non-whitespace characters in `str` by replacing them with `obfuscationCharacter`
  and returns the result.
  
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