local effectRadius
local effectType

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  effectRadius = config.getParameter("effectRadius")
  effectType = config.getParameter("effectType")
end

function update(dt)
  oldUpdate(dt)

  local queried = world.entityQuery(object.position(), effectRadius, {includedTypes = {"player"}})

  for _, playerId in ipairs(queried) do
    world.sendEntityMessage(playerId, "applyStatusEffect", effectType)
  end
end