local poisonRadius
local poisonEffectType

function init()
  poisonRadius = config.getParameter("poisonRadius")
  poisonEffectType = config.getParameter("poisonEffectType")
end

function update(dt)
  local queried = world.entityQuery(object.position(), poisonRadius, {includedTypes = {"player"}})
  
  for _, playerId in ipairs(queried) do
    world.sendEntityMessage(playerId, "applyStatusEffect", poisonEffectType)
  end
end