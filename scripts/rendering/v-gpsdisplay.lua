require "/scripts/util.lua"
require "/scripts/vec2.lua"

--[[
  Displays the player's position using localAnimator if the player has a GPS item equipped that is active.
]]

local oldInit = init or function() end
local oldUpdate = update or function() end

local itemName
local glyphHSpacing
local digitPath
local xDisplayPath
local yDisplayPath
local displayOffset

function init()
  oldInit()

  -- The spacing to put between each glyph horizontally. DOES NOT account for the width of the image itself. Measured in
  -- blocks.
  glyphHSpacing = 0.5
  -- The spacing to put between each glyph vertically. DOES NOT account for the height of the image itself. Measured in
  -- blocks.
  glyphVSpacing = 1
  digitPath = "/interface/v-gpsdisplay/digit.png"
  xDisplayPath = "/interface/v-gpsdisplay/xdisplay.png"
  yDisplayPath = "/interface/v-gpsdisplay/ydisplay.png"
  displayOffset = {1, 0}
end

function update(dt)
  oldUpdate(dt)  -- Implicitly clears drawables

  -- If the player has an active GPS...
  if player.getItemWithParameter("v-gpsIsActive", true) then
    local ownPos = world.entityPosition(player.id())
    local flooredXPos = math.floor(ownPos[1])
    local flooredYPos = math.floor(ownPos[2])

    -- The xDisplay and yDisplay drawables each consist of 2 glyphs. The third additional glyph offset is a space
    -- Show X coordinate
    showGlyph(xDisplayPath, displayOffset)
    showNumber(flooredXPos, vec2.add(displayOffset, {glyphHSpacing * 3, 0}))

    -- Show Y coordinate
    showGlyph(yDisplayPath, vec2.add(displayOffset, {0, -glyphVSpacing}))
    showNumber(flooredYPos, vec2.add(displayOffset, {glyphHSpacing * 3, -glyphVSpacing}))
  end
end

---Shows a number `number` with offset `startingOffset` determining the offset from the center of the player. The
---position is located at the bottom-left corner of the displayed number.
---@param number integer
---@param startingOffset Vec2F
function showNumber(number, startingOffset)
  local xOffset = 0  -- Declared up here because it is used all throughout the function

  -- If the number is negative...
  if number < 0 then
    -- Add a negative symbol, increase the xOffset, and make the number positive for displaying purposes
    showDigitChar("-", {startingOffset[1] + xOffset, startingOffset[2]})

    xOffset = xOffset + glyphHSpacing  -- Increase xOffset by glyphHSpacing
    number = -number
  end

  local digits = {}

  -- While there are digits to extract...
  while number ~= 0 do
    -- Extract the next digit. modulus 10 removes the digits to the left of the first one. Integer-dividing by 10 chops
    -- off the first digit
    local digit = number % 10
    number = number // 10

    table.insert(digits, digit)
  end

  -- Traverse the list backwards since the digits come out backwards
  for i = #digits, 1, -1 do
    -- Add the drawable
    showDigitChar(tostring(digits[i]), vec2.add(startingOffset, {xOffset, 0}))

    xOffset = xOffset + glyphHSpacing  -- Increase xOffset by glyphHSpacing
  end
end

---Shows a digit character `ch` with offset `offset`.
---@param ch string
---@param offset Vec2F
function showDigitChar(ch, offset)
  showGlyph(string.format("%s:%s", digitPath, ch), offset)
end

---Shows a glyph with path `path` and relative position `offset`. This drawable is fullbright, not centered,
---and has a render layer of `overlay+5`.
---@param path string
---@param offset Vec2F
function showGlyph(path, offset)
  localAnimator.addDrawable({
    image = path,
    position = offset,
    fullbright = true,
    centered = false
  }, "overlay+5")
end