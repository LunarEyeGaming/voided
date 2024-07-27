require "/scripts/vec2.lua"
require "/scripts/v-ellipse.lua"

local numPoints
local fillColor
local outlineColor

local testTable

function init()
  script.setUpdateDelta(3)

  numPoints = animationConfig.animationParameter("ellipseNumPoints")
  fillColor = animationConfig.animationParameter("ellipseFillColor")
  outlineColor = animationConfig.animationParameter("ellipseOutlineColor")
  outlineThickness = animationConfig.animationParameter("ellipseOutlineThickness")

  dt = script.updateDt()
end

function update()
  localAnimator.clearDrawables()

  -- Get telegraph region config (which is an ellipse with center `center` and 2D radius `radius`).
  local ellipse = animationConfig.animationParameter("telegraphRegionConfig")

  -- Abort if ellipse is not defined yet.
  if not ellipse then
    return
  end

  local points = {}

  -- Generate a poly that forms an ellipse.
  for i = 1, numPoints do
    table.insert(points, vEllipse.point(ellipse.center, ellipse.radius, numPoints, i))
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