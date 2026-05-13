require "/scripts/vec2.lua"
require "/scripts/v-util.lua"

local glyphHSpacing
local digitPath
local renderLayer

local liquidIconOffset
local liquidCountOffset

function init()
  -- The spacing to put between each glyph horizontally. DOES NOT account for the width of the image itself. Measured in
  -- blocks.
  glyphHSpacing = 0.5
  digitPath = "/items/active/weapons/unique/v-liquidgun/digit.png"
  renderLayer = "overlay+5"

  liquidIconOffset = {0, 0}
  liquidCountOffset = {0.5, -1.25}
end

function update(dt)
  localAnimator.clearDrawables()

  local currentLiquid = animationConfig.animationParameter("currentLiquid")
  local aimPos = activeItemAnimation.ownerAimPosition()

  if currentLiquid then
    drawDisplay(currentLiquid, aimPos)
  end
end

---Draws the display for the given liquid at the given position.
---@param liquid ItemDescriptor
---@param pos Vec2F
function drawDisplay(liquid, pos)
  local itemConfig = root.itemConfig(liquid)

  if itemConfig.config.inventoryIcon then
    local absolutePath

    -- Use the string directly if it's already absolute. Otherwise, make it absolute.
    if vUtil.strStartsWith(itemConfig.config.inventoryIcon, "/") then
      absolutePath = itemConfig.config.inventoryIcon
    else
      absolutePath = itemConfig.directory .. itemConfig.config.inventoryIcon
    end

    showGlyph(absolutePath, vec2.add(pos, liquidIconOffset))
  end

  local count = liquid.count or 0

  showNumber(count, vec2.add(pos, liquidCountOffset))
end

---Shows a number `number` at position `startingPosition`. The position is located at the bottom-left corner of the
---displayed number.
---@param number integer
---@param startingPosition Vec2F
function showNumber(number, startingPosition)
  local xOffset = 0  -- Declared up here because it is used all throughout the function

  -- If the number is negative...
  if number < 0 then
    -- Add a negative symbol, increase the xOffset, and make the number positive for displaying purposes
    showDigitChar("-", {startingPosition[1] + xOffset, startingPosition[2]})

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
    showDigitChar(tostring(digits[i]), vec2.add(startingPosition, {xOffset, 0}))

    xOffset = xOffset + glyphHSpacing  -- Increase xOffset by glyphHSpacing
  end
end

---Shows a digit character `ch` with position `position`.
---@param ch string
---@param position Vec2F
function showDigitChar(ch, position)
  showGlyph(string.format("%s:%s", digitPath, ch), position)
end

---Shows a glyph with path `path` and position `position`. This drawable is fullbright, not centered,
---and has a render layer of `renderLayer`.
---@param path string
---@param position Vec2F
function showGlyph(path, position)
  localAnimator.addDrawable({
    image = path,
    position = position,
    fullbright = true,
    centered = false
  }, renderLayer)
end