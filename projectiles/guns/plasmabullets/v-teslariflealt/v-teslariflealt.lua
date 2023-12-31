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
      if detonateMultiple then
        for _, orb in ipairs(queriedOrbs) do
          detonateProjectile(orb)
        end
      else
        detonateProjectile(queriedOrbs[1])
      end
      projectile.die()
    end
  end
end

function detonateProjectile(projectileId)
  world.sendEntityMessage(projectileId, "v-triggerDetonation", projectile.power() * detonateDamageMultiplier, projectile.powerMultiplier())
end