local CURSOR_INRANGE = 0
local CURSOR_OUTOFRANGE = 1
local CURSOR_CANFIX = 2

local COLOR_ORANGE = {255, 194, 150, 191}
local COLOR_BLUE = {150, 180, 255, 128}

function update()
  localAnimator.clearDrawables()

  local cursorState = animationConfig.animationParameter("cursorState")

  local cursorImage = animationConfig.animationParameter("cursorImage")
  local lensHighlightImage = animationConfig.animationParameter("lensHighlightImage")
  local lensPositions = animationConfig.animationParameter("lensPositions") or {}
  local position = activeItemAnimation.ownerAimPosition()

  local highlightColor, frameIndex
  if cursorState == CURSOR_CANFIX or cursorState == CURSOR_INRANGE then
    highlightColor = COLOR_ORANGE
    frameIndex = "valid.1"
  else
    highlightColor = COLOR_BLUE
    frameIndex = "invalid.1"
  end

  for _, pos in ipairs(lensPositions) do
    localAnimator.addDrawable({
      image = lensHighlightImage,
      position = pos,
      color = COLOR_ORANGE,
      fullbright = true
    })
  end

  localAnimator.addDrawable({
    image = string.format("%s:%s", cursorImage, frameIndex),
    position = position,
    color = highlightColor,
    fullbright = true
  })
end
