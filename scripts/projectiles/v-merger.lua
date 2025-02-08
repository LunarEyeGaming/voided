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
    local queriedMergers = world.entityQuery(mcontroller.position(), mergeRadius, {
      callScript = "v_isMergerType",
      callScriptArgs = {targetType},
      includedTypes = {"projectile"},
      order = "nearest"
    })
    -- If the second condition is not included then it will detonate based on where the merger was *previously* and not
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
    projectile.processAction(nonMergeAction)
  end
end