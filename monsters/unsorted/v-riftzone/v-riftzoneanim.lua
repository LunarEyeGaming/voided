require "/scripts/poly.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/v-ellipse.lua"

local oldUpdate = update or function() end

function update()
  localAnimator.clearDrawables()

  oldUpdate(dt)

  local riftSize = animationConfig.animationParameter("riftSize")

  local numPoints = 50
  local riftPoly = {}
  -- Generate a poly that forms an ellipse.
  for i = 1, numPoints do
    table.insert(riftPoly, vEllipse.point({0, 0}, riftSize + util.randomInRange({-0.5, 0.5}), i, numPoints))
  end

  if riftPoly then
    drawRiftPoly(riftPoly, entity.position())
  end
end

function drawRiftPoly(poly_, center)
  local outlineThickness = 1
  local outlineColor = {255, 255, 255, 26}
  local bgColor = {0, 0, 0}
  local darknessColor = {18, 5, 20, 127}
  local outlinePoly = {}
  for _, point in ipairs(poly_) do
    local norm = vec2.norm(point)
    table.insert(outlinePoly, vec2.add(point, vec2.mul(norm, outlineThickness)))
  end
  localAnimator.addDrawable({
    poly = poly_,
    color = bgColor,
    position = center,
    fullbright = true
  }, "BackgroundOverlay-5")
  localAnimator.addDrawable({
    poly = poly_,
    color = darknessColor,
    position = center,
    fullbright = true
  }, "ForegroundOverlay+256")
  -- localAnimator.addDrawable({
  --   poly = outlinePoly,
  --   color = outlineColor,
  --   position = center,
  --   fullbright = true
  -- }, "ForegroundOverlay+255")

  -- Draw outline on top of fill
  for i = 1, #poly_ - 1 do
    localAnimator.addDrawable({
      line = {poly_[i], poly_[i + 1]},
      width = outlineThickness,
      position = center,
      color = outlineColor,
      fullbright = true
    }, "ForegroundOverlay+257")
  end

  -- Add last point after loop to complete the outline
  localAnimator.addDrawable({
    line = {poly_[#poly_], poly_[1]},
    width = outlineThickness,
    position = center,
    color = outlineColor,
    fullbright = true
  }, "ForegroundOverlay+257")
end