require "/scripts/vec2.lua"

local isStuck
local prevPosition

function init()
  isStuck = false
  prevPosition = mcontroller.position()
end

function update(dt)
  if not isStuck then
    -- Make a guess about the entities that the projectile has hit.
    local queried = world.entityLineQuery(prevPosition, mcontroller.position(), {includedTypes = {"creature"}})

    for _, entityId in ipairs(queried) do
      if world.entityCanDamage(projectile.sourceEntity(), entityId) then
        world.spawnProjectile("v-clouddartstuck", mcontroller.position(), projectile.sourceEntity(), vec2.withAngle(mcontroller.rotation()), false, {
          power = projectile.power(),
          powerMultiplier = projectile.powerMultiplier(),
          timeToLive = projectile.timeToLive(),
          stuckEntityId = entityId,
          -- Offset relative to entity.
          stuckOffset = world.distance(prevPosition, world.nearestTo(prevPosition, world.entityPosition(entityId)))
        })

        projectile.die()

        return  -- This skips all other entities and stops the check for sticky collision.
      end
    end

    isStuck = mcontroller.stickingDirection() ~= nil
    prevPosition = mcontroller.position()
  end
end