require "/scripts/projectiles/v-mergergeneric.lua"

local detonateDelay
local detonateDamageMultiplier
local detonateTimer

local merger

function init()
  detonateDelay = config.getParameter("detonateDelay")
  detonateDamageMultiplier = config.getParameter("detonateDamageMultiplier", 1.0)
  detonateTimer = detonateDelay

  merger = VMerger:new("v-teslarifleorb", config.getParameter("detonateRadius"), config.getParameter("detonateMultiple"), true)
end

function update(dt)
  detonateTimer = detonateTimer - dt
  if detonateTimer <= 0 then
    merger:process(projectile.power() * detonateDamageMultiplier, projectile.powerMultiplier())
  end
end

function detonateProjectile(projectileId)
  world.sendEntityMessage(projectileId, "v-triggerDetonation", projectile.power() * detonateDamageMultiplier, projectile.powerMultiplier())
end