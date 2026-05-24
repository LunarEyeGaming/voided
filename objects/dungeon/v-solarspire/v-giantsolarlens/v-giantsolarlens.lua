require "/scripts/vec2.lua"

local beamOscillateMinAmplitude
local beamOscillateMaxAmplitude
local beamOscillatePeriod

local beamOscillateTimer

function init()
  local direction = config.getParameter("direction")
  local angle
  if direction then
    angle = vec2.angle(direction)
  else
    angle = config.getParameter("angle", 0) * math.pi / 180
  end
  angle = angle + config.getParameter("angleOffset", 0) * math.pi / 180
  animator.resetTransformationGroup("lens")
  animator.rotateTransformationGroup("lens", angle, config.getParameter("center"))

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