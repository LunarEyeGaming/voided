local mergeRadius
local nonMergeAction
local targetType
local mergeDelay
local mergeTimer
local hasMerged

function init()
  mergeRadius = config.getParameter("mergeRadius")
  nonMergeAction = config.getParameter("nonMergeAction")
  targetType = config.getParameter("targetType")
  mergeDelay = config.getParameter("mergeDelay", 0)
  mergeTimer = mergeDelay
  hasMerged = false
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
    projectile.processAction(nonMergeAction)
  end
end