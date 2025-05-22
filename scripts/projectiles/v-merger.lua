require "/scripts/projectiles/v-mergergeneric.lua"

local nonMergeAction
local mergeDelay
local mergeTimer

local merger  ---@type VMerger

function init()
  mergeRadius = config.getParameter("mergeRadius")
  nonMergeAction = config.getParameter("nonMergeAction")
  targetType = config.getParameter("targetType")
  mergeDelay = config.getParameter("mergeDelay", 0)
  mergeTimer = mergeDelay

  merger = VMerger:new(config.getParameter("targetType"), config.getParameter("mergeRadius"), false, true)
end

function update(dt)
  mergeTimer = mergeTimer - dt
  if mergeTimer <= 0 then
    merger:process(projectile.sourceEntity())
  end
end

function destroy()
  if not merger:isMerged() then
    projectile.processAction(nonMergeAction)
  end
end