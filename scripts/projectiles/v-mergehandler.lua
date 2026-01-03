require "/scripts/projectiles/v-mergergeneric.lua"

local actionOnMerge
local actionOnNonMerge

function init()
  actionOnMerge = config.getParameter("actionOnMerge")
  actionOnNonMerge = config.getParameter("actionOnNonMerge")
  mergeHandlerType = config.getParameter("mergeHandlerType")

  vMergeHandler.set(mergeHandlerType, false, function(_, senderSourceEntity)
    -- Ensure that the sender has the same source entity as the current projectile.
    return senderSourceEntity == projectile.sourceEntity()
  end)
end

function update(dt)

end

function destroy()
  if vMergeHandler.isMerged() then
    projectile.processAction(actionOnMerge)
  else
    projectile.processAction(actionOnNonMerge)
  end
end