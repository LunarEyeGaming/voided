require "/scripts/vec2.lua"

local nextProjectile
local sourceId

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldDestroy = destroy or function() end


function init()
  oldInit()

  sourceId = projectile.sourceEntity()
  nextProjectile = config.getParameter("nextProjectile")
end

function update(dt)
  oldUpdate(dt)

  if not sourceId or not world.entityExists(sourceId) then
    projectile.die()
    return
  end
end

function destroy()
  oldDestroy()

  if nextProjectile then
    local projectileId = world.spawnProjectile(nextProjectile, mcontroller.position(), sourceId, vec2.withAngle(mcontroller.rotation()), false, {
      power = projectile.power(),
      powerMultiplier = projectile.powerMultiplier()
    })
    if projectileId then
      world.sendEntityMessage(sourceId, "projectileSpawned", projectileId)
    end
  end
end