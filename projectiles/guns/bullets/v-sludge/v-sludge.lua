require "/scripts/projectiles/v-mergergeneric.lua"

local liveCollisionAction
local mergeDelay
local mergeTimer
local deadCollisionAction

function init()
  liveCollisionAction = config.getParameter("liveCollisionAction")
  mergeDelay = config.getParameter("mergeDelay", 0)
  mergeTimer = mergeDelay

  deadCollisionAction = config.getParameter("deadCollisionAction")

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
    if mcontroller.isColliding() then
      projectile.processAction(deadCollisionAction)
    else
      projectile.processAction(liveCollisionAction)
    end
  end
end