require "/scripts/v-animator.lua"
require "/scripts/util.lua"

local startColor
local endColor
local transitionTime

local timeElapsed
function init()
  -- startColor and endColor are RBGA color tables.
  startColor = config.getParameter("startColor")
  endColor = config.getParameter("endColor")
  transitionTime = config.getParameter("transitionTime")

  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)

  animator.playSound("burn", -1)
  animator.setSoundVolume("burn", 0)

  timeElapsed = 0

  script.setUpdateDelta(6)
end

function update(dt)
  timeElapsed = timeElapsed + dt

  local progress = math.min(1.0, timeElapsed / transitionTime)
  local color = vAnimator.lerpColor(progress, startColor, endColor)
  setFadeColor(color)

  animator.setSoundVolume("burn", progress)
end

-- Sets the fade directive to use the provided color. The RGB channels are used as normal, but the A channel is used to
-- set the fade amount.
function setFadeColor(color)
  local fadeColor = {color[1], color[2], color[3]}
  local fadeAmount = color[4] / 255
  effect.setParentDirectives(string.format("fade=%s=%s", vAnimator.colorToString(fadeColor), fadeAmount))
end