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

  message.setHandler("v-titanbouncingprojectile-freeze", function()
    mcontroller.setVelocity({0, 0})
  end)
end

function destroy()
  oldDestroy()

  if target and world.entityExists(target) then
    -- Get target direction.
    local targetDirection = world.distance(world.entityPosition(target), mcontroller.position())
    -- Spawn targeted projectile
    local params = {
      timeToLive = 0.75,
      power = projectile.power(),
      powerMultiplier = projectile.powerMultiplier()
    }
    if config.getParameter("homing") then
      params.projectileType = "v-titanriftprojectilehoming"
    end
    local id = world.spawnProjectile("v-titantargetedprojectile", mcontroller.position(), projectile.sourceEntity(),
    targetDirection, false, params)
    -- Mark target
    vWorld.sendEntityMessage(id, "setTarget", target)
  end
end