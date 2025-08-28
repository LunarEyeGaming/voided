local CURSOR_INRANGE = 0
local CURSOR_OUTOFRANGE = 1
local CURSOR_CANFIX = 2

local COLOR_GREEN = {150, 255, 150, 191}
local COLOR_RED = {255, 150, 150, 128}

function update()
  localAnimator.clearDrawables()

  local cursorState = animationConfig.animationParameter("cursorState")

  local cursorImage = animationConfig.animationParameter("cursorImage")
  local lensHighlightImage = animationConfig.animationParameter("lensHighlightImage")
  local lensPositions = animationConfig.animationParameter("lensPositions") or {}
  local position = activeItemAnimation.ownerAimPosition()

  local highlightColor
  if cursorState == CURSOR_CANFIX or cursorState == CURSOR_INRANGE then
    highlightColor = COLOR_GREEN
  else
    highlightColor = COLOR_RED
  end

  for _, pos in ipairs(lensPositions) do
    localAnimator.addDrawable({
      image = lensHighlightImage,
      position = pos,
      color = COLOR_GREEN,
      fullbright = true
    })
  end

  localAnimator.addDrawable({
    image = cursorImage,
    position = position,
    color = highlightColor,
    fullbright = true
  })
end
