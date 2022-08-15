local detonateRadius
local detonateDelay
local detonateMultiple
local detonateDamageMultiplier
local detonateTimer

function init()
  detonateRadius = config.getParameter("detonateRadius")
  detonateDelay = config.getParameter("detonateDelay")
  detonateMultiple = config.getParameter("detonateMultiple")
  detonateDamageMultiplier = config.getParameter("detonateDamageMultiplier", 1.0)
  detonateTimer = detonateDelay
end

function update(dt)
  detonateTimer = detonateTimer - dt
  if detonateTimer <= 0 then
    local queriedOrbs = world.entityQuery(mcontroller.position(), detonateRadius, {callScript = "v_isTeslaRifleOrb", includedTypes = {"projectile"}, order = "nearest"})
    if #queriedOrbs > 0 then
      -- projectile.die() is placed in separate cases to prevent it from popping out of existence without doing anything.
      if detonateMultiple then
        for _, orb in ipairs(queriedOrbs) do
          detonateProjectile(orb)
        end
        projectile.die()
      elseif world.magnitude(world.entityPosition(queriedOrbs[1]), mcontroller.position()) < detonateRadius then
        detonateProjectile(queriedOrbs[1])
        projectile.die()
      end
    end
  end
end

function detonateProjectile(projectileId)
  world.sendEntityMessage(projectileId, "v-triggerDetonation", projectile.power() * detonateDamageMultiplier, projectile.powerMultiplier())
end