require "/scripts/vec2.lua"

local appearDelay
local timer

local projectileId

function init()
  appearDelay = config.getParameter("appearDelay")
  timer = appearDelay
end

function update(dt)
  if timer then
    timer = timer - dt
    if timer <= 0 then
      local velocity = mcontroller.velocity()
      local speed = vec2.mag(velocity)
      local direction = vec2.norm(velocity)
      projectileId = world.spawnProjectile("v-riftzonemeteor", mcontroller.position(), projectile.sourceEntity(), direction, false, {
        power = projectile.power(),
        powerMultiplier = projectile.powerMultiplier(),
        speed = speed
      })
      timer = nil
    end
  elseif not projectileId or not world.entityExists(projectileId) then
    projectile.die()
  end
end