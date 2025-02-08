local mergeRadius
local liveCollisionAction
local targetType
local mergeDelay
local mergeTimer
local hasMerged
local deadCollisionAction

function init()
  mergeRadius = config.getParameter("mergeRadius")
  liveCollisionAction = config.getParameter("liveCollisionAction")
  targetType = config.getParameter("targetType")
  mergeDelay = config.getParameter("mergeDelay", 0)
  mergeTimer = mergeDelay
  hasMerged = false

  deadCollisionAction = config.getParameter("deadCollisionAction")
end

function update(dt)
  mergeTimer = mergeTimer - dt
    if mergeTimer <= 0 then
    local queriedMergers = world.entityQuery(mcontroller.position(), mergeRadius, {callScript = "v_isMergerType", callScriptArgs = {targetType}, includedTypes = {"projectile"}, order = "nearest"})
    -- If the second condition is not included then it will detonate based on where the globe was *previously* and not
    -- where it is right now.
    if #queriedMergers > 0 and world.magnitude(world.entityPosition(queriedMergers[1]), mcontroller.position()) < mergeRadius then
      world.sendEntityMessage(queriedMergers[1], "v-handleMerge", projectile.sourceEntity())
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
  end
end