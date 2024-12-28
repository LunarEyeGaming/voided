require "/scripts/v-world.lua"

local oldInit = init or function() end
local oldDestroy = destroy or function() end

local target

function init()
  oldInit()

  message.setHandler("v-titanbouncingprojectile-fling", function(_, _, targetId)
    target = targetId
    projectile.die()
  end)
end

function destroy()
  oldDestroy()

  if target and world.entityExists(target) then
    -- Get target direction.
    local targetDirection = world.distance(world.entityPosition(target), mcontroller.position())
    -- Spawn targeted projectile
    local id = world.spawnProjectile("delayedplasmaball", mcontroller.position(), projectile.sourceEntity(),
    targetDirection, false, {
      timeToLive = 0.75,
      power = projectile.power(),
      powerMultiplier = projectile.powerMultiplier()
    })
    -- Mark target
    vWorld.sendEntityMessage(id, "setTarget", target)
  end
end