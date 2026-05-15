local effectRadius
local effectType
local effectDuration
local requireInput

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  effectRadius = config.getParameter("statusEffectConfig.effectRadius")
  effectType = config.getParameter("statusEffectConfig.effectType")
  effectDuration = config.getParameter("statusEffectConfig.effectDuration")
  requireInput = config.getParameter("statusEffectConfig.requireInput")
end

function update(dt)
  oldUpdate(dt)

  -- Optionally require input to activate.
  if not requireInput or object.getInputNodeLevel(0) then
    local queried = world.entityQuery(object.position(), effectRadius, {includedTypes = {"player"}})

    for _, playerId in ipairs(queried) do
      world.sendEntityMessage(playerId, "applyStatusEffect", effectType, effectDuration)
    end
  end
end