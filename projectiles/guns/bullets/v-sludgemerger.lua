local mergeRadius
local targetType
local mergeDelay
local mergeTimer
local hasMerged

local liveCollisionAction
local deadCollisionAction
local actionAsMerger

function init()
  mergeRadius = config.getParameter("mergeRadius")
  targetType = config.getParameter("targetType")
  mergeDelay = config.getParameter("mergeDelay", 0)
  mergeTimer = mergeDelay
  hasMerged = false

  liveCollisionAction = config.getParameter("liveCollisionAction")
  deadCollisionAction = config.getParameter("deadCollisionAction")
end

function update(dt)
  mergeTimer = mergeTimer - dt
    if mergeTimer <= 0 then
    queriedGlobes = world.entityQuery(mcontroller.position(), mergeRadius, {callScript = "v_isMergerType", callScriptArgs = {targetType}, includedTypes = {"projectile"}, order = "nearest"})
    -- If the second condition is not included then it will detonate based on where the globe was *previously* and not
    -- where it is right now.
    if #queriedGlobes > 0 and world.magnitude(world.entityPosition(queriedGlobes[1]), mcontroller.position()) < mergeRadius then
      world.sendEntityMessage(queriedGlobes[1], "v-handleMerge")
      hasMerged = true
      projectile.die()
    end
  end
end

function destroy()
  if not hasMerged then
    if mcontroller.isColliding() then
      projectile.processAction(deadCollisionAction)
    else
      projectile.processAction(liveCollisionAction)
    end
  elseif isMerger then
    projectile.processAction(actionAsMerger)
  end
end