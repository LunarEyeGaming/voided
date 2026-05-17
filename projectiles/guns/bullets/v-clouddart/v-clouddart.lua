require "/scripts/vec2.lua"

local stuckProjectile
local isStuck

function init()
  stuckProjectile = config.getParameter("stuckProjectile")
  isStuck = false
end

function update(dt)
  if not isStuck then

    isStuck = mcontroller.stickingDirection() ~= nil
  end
end

function hit(entityId)
  -- Avoid sticking to enemies if already stuck to terrain.
  if isStuck then
    return
  end

  world.spawnProjectile(stuckProjectile, mcontroller.position(), projectile.sourceEntity(), vec2.withAngle(mcontroller.rotation()), false, {
    power = projectile.power(),
    powerMultiplier = projectile.powerMultiplier(),
    timeToLive = projectile.timeToLive(),
    stuckEntityId = entityId,
    -- Offset relative to entity.
    stuckOffset = world.distance(mcontroller.position(), world.nearestTo(mcontroller.position(), world.entityPosition(entityId)))
  })

  projectile.die()
end