--[[
  Script that inflicts a status effect on all "creatures" within close proximity to the player. Used by the 
  "v-toxikitesetbonus" status effect. How close is specified by the "effectRadius" parameter, and the effect to apply is
  given by the "effectName" parameter. The effect duration is specified by the "effectDuration" parameter. All receivers
  of the status effect will have this script's parent entity as the source entity.
]]

local effectName
local effectDuration
local effectRadius

function init()
  effectName = config.getParameter("effectName")
  effectDuration = config.getParameter("effectDuration")
  effectRadius = config.getParameter("effectRadius")
end

function update(dt)
  local queried = world.entityQuery(mcontroller.position(), effectRadius, {includedTypes = {"creature"}, withoutEntityId = entity.id()})
  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "applyStatusEffect", effectName, effectDuration, entity.id())
  end
end