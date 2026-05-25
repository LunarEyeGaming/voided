require "/scripts/projectiles/v-mergergeneric.lua"

local actionOnMerge
local actionOnNonMerge
local mergeDelay

local mergeTimer

function init()
  actionOnMerge = config.getParameter("actionOnMerge")
  actionOnNonMerge = config.getParameter("actionOnNonMerge")
  mergeHandlerType = config.getParameter("mergeHandlerType")
  mergeDelay = config.getParameter("mergeDelay", 0)

  vMergeHandler.set(mergeHandlerType, false, function(_, senderSourceEntity)
    -- Ensure that the sender has the same source entity as the current projectile and that the projectile can merge
    -- now.
    return mergeTimer <= 0 and senderSourceEntity == projectile.sourceEntity()
  end)

  mergeTimer = mergeDelay
end

function update(dt)
  mergeTimer = mergeTimer - dt
end

function destroy()
  if vMergeHandler.isMerged() then
    projectile.processAction(actionOnMerge)
  else
    projectile.processAction(actionOnNonMerge)
  end
end