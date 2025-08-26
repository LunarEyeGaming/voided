require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-animator.lua"
require "/scripts/statuseffects/v-tickdamage.lua"

local burnDamage
local tickTime
local tickDelay

local tickDamage

local startColor
local endColor
local transitionTime

local timeElapsed

function init()
  script.setUpdateDelta(6)

  burnDamage = config.getParameter("burnDamage")
  tickTime = config.getParameter("tickTime")
  tickDelay = config.getParameter("tickDelay")

  tickDamage = VTickDamage:new{
    kind = "fire",
    amount = burnDamage,
    damageType = "IgnoresDef",
    interval = tickTime,
    firstTickDelay = tickDelay,
    source = entity.id() }


  -- startColor and endColor are RBGA color tables.
  startColor = config.getParameter("startColor")
  endColor = config.getParameter("endColor")
  transitionTime = config.getParameter("transitionTime")

  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)

  animator.playSound("burn", -1)
  animator.setSoundVolume("burn", 0)

  timeElapsed = 0
end

function update(dt)
  if status.statPositive("v-ministarHeatTickMultiplier") then
    tickDamage.interval = tickTime * status.stat("v-ministarHeatTickMultiplier")
  end

  local multiplier = 1 - status.stat("v-ministarHeatResistance")

  -- Update damage amount.
  tickDamage.damageRequest.damage = burnDamage * multiplier
  tickDamage:update(dt)  -- Run the tickDamage object for one tick.

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