require "/scripts/poly.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/v-ellipse.lua"

local particleEmitters

local oldUpdate = update or function() end

function update()
  localAnimator.clearDrawables()

  oldUpdate(dt)

  -- if not particleEmitters then
  --   fetchParticleEmitters()
  -- else
  --   updateParticles()
  -- end
  updateRift()
end

function fetchParticleEmitters()
  particleEmitters = animationConfig.animationParameter("riftParticleEmitters")

  -- for name, emitter in pairs(particleEmitters) do
  --   local particle = emitter.particle
  --   if particle.approach[1] ~= 0 or particle.approach[2] ~= 0 then
  --     sb.logWarn("%s: Emitters with changing velocities are not supported", name)
  --     particleEmitters[name] = nil
  --     goto continue
  --   end

  --   ::continue::
  -- end
end

function updateParticles()
  local activeParticleEmitters = animationConfig.animationParameter("riftActiveParticleEmitters")
  local velocity = world.entityVelocity(entity.id())

  for name, emitter in pairs(particleEmitters) do
    if activeParticleEmitters[name] then
      -- Get velocity

    end
  end
end

function simulate(particlePosition, particleVelocity, zonePosition, zoneVelocity, zoneSize, stepSize, maxTime)
  local time = 0
  -- Copy vectors
  local pp = {particlePosition[1], particlePosition[2]}
  local zp = {zonePosition[1], zonePosition[2]}

  while time <= maxTime do
    -- Update positions
    pp[1] = pp[1] + particleVelocity[1] * stepSize
    pp[2] = pp[2] + particleVelocity[2] * stepSize
    zp[1] = zp[1] + zoneVelocity[1] * stepSize
    zp[2] = zp[2] + zoneVelocity[2] * stepSize

    -- Check if

    time = time + stepSize
  end
end

function updateRift()
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