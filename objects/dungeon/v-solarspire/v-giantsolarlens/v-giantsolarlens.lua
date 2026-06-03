require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local beamOscillateMinAmplitude
local beamOscillateMaxAmplitude
local beamOscillatePeriod

local beamOscillateTimer

function init()
  local center = config.getParameter("center", {0, 0})
  local direction = config.getParameter("direction")
  local angle
  if direction then
    angle = vec2.angle(direction)
  else
    angle = config.getParameter("angle", 0) * math.pi / 180
  end
  angle = angle + config.getParameter("angleOffset", 0) * math.pi / 180
  animator.resetTransformationGroup("lens")
  animator.rotateTransformationGroup("lens", angle, center)
  local damageConfig = config.getParameter("damageConfig")
  if damageConfig then
    damageConfig.poly = poly.translate(poly.rotate(poly.translate(damageConfig.poly, vec2.mul(center, -1)), angle), center)
    object.setDamageSources({damageConfig})
  end

  beamOscillateMinAmplitude = config.getParameter("beamOscillateMinAmplitude", 0.5)
  beamOscillateMaxAmplitude = config.getParameter("beamOscillateMaxAmplitude", 1)
  beamOscillatePeriod = config.getParameter("beamOscillatePeriod", 1)

  beamOscillateTimer = 0
end

function update(dt)
  beamOscillateTimer = (beamOscillateTimer + dt) % beamOscillatePeriod
  animator.resetTransformationGroup("beam")
  local xScale = beamOscillateMinAmplitude + (beamOscillateMaxAmplitude - beamOscillateMinAmplitude) * (math.cos(2 * math.pi * beamOscillateTimer / beamOscillatePeriod) / 2 + 0.5)
  animator.scaleTransformationGroup("beam", {xScale, 1})
end