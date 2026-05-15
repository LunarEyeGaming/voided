-- This script exists so that projectiles can inflict status effects independent of the status effects that it inflicts
-- upon dealing damage.

local effectRadius
local effectType
local effectDuration

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  effectRadius = config.getParameter("statusEffectConfig.effectRadius")
  effectType = config.getParameter("statusEffectConfig.effectType")
  effectDuration = config.getParameter("statusEffectConfig.effectDuration")
end

function update(dt)
  oldUpdate(dt)

  local queried = world.entityQuery(mcontroller.position(), effectRadius, {includedTypes = {"player"}})

  for _, playerId in ipairs(queried) do
    world.sendEntityMessage(playerId, "applyStatusEffect", effectType, effectDuration)
  end
end