require "/scripts/vec2.lua"
require "/scripts/v-ellipse.lua"
require "/scripts/v-animator.lua"
require "/scripts/v-util.lua"

local numPoints
local fillColorCfg
local outlineColorCfg
local outlineThickness
local flashTime

local flashTimer

function init()
  script.setUpdateDelta(3)

  numPoints = animationConfig.animationParameter("ellipseNumPoints")
  fillColorCfg = animationConfig.animationParameter("ellipseFillColor")
  outlineColorCfg = animationConfig.animationParameter("ellipseOutlineColor")
  outlineThickness = animationConfig.animationParameter("ellipseOutlineThickness")
  flashTime = animationConfig.animationParameter("ellipseFlashTime")

  flashTimer = 0

  dt = script.updateDt()
end

function update()
  localAnimator.clearDrawables()

  flashTimer = flashTimer + dt

  -- If the flash timer exceeds flashTime...
  if flashTimer >= flashTime then
    -- Reset it
    flashTimer = 0
  end

  -- Calculate colors (which are set to transition between two colors to create a flashing animation)
  local ratio = vUtil.pingPong(flashTimer / flashTime)
  local fillColor = vAnimator.lerpColor(ratio, fillColorCfg.high, fillColorCfg.low)
  local outlineColor = vAnimator.lerpColor(ratio, outlineColorCfg.high, outlineColorCfg.low)

  -- Get telegraph region config (which is an ellipse with center `center` and 2D radius `radius`).
  local ellipse = animationConfig.animationParameter("telegraphRegionConfig")

  -- Abort if ellipse is not defined yet.
  if not ellipse then
    return
  end

  local points = {}

  -- Generate a poly that forms an ellipse.
  for i = 1, numPoints do
    table.insert(points, vEllipse.point(ellipse.center, ellipse.radius, i, numPoints))
  end

  -- Draw fill
  localAnimator.addDrawable({
    poly = points,
    position = {0, 0},
    color = fillColor,
    fullbright = true
  })

  -- Draw outline on top of fill
  for i = 1, #points - 1 do
    localAnimator.addDrawable({
      line = {points[i], points[i + 1]},
      width = outlineThickness,
      position = {0, 0},
      color = outlineColor,
      fullbright = true
    })
  end

  -- Add last point after loop to complete the outline
  localAnimator.addDrawable({
    line = {points[#points], points[1]},
    width = outlineThickness,
    position = {0, 0},
    color = outlineColor,
    fullbright = true
  })
end