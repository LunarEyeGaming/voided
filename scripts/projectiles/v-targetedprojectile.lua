local target

function init()
  message.setHandler("setTarget", function(_, _, entityId)
    target = entityId
  end)
end

function update()
  if not target or not world.entityExists(target) then return end

  local targetPosition = world.entityPosition(target)
  if targetPosition then
    local toTarget = world.distance(targetPosition, mcontroller.position())
    local angle = math.atan(toTarget[2], toTarget[1])
    mcontroller.setRotation(angle)
  end

  if projectile.sourceEntity() and not world.entityExists(projectile.sourceEntity()) then
    projectile.die()
  end
end

function destroy()
  if projectile.sourceEntity() and world.entityExists(projectile.sourceEntity()) then
    local rotation = mcontroller.rotation()

    local projectileType = config.getParameter("projectileType")
    local projectileParameters = config.getParameter("projectileParameters", {})
    local inheritDamageFactor = config.getParameter("inheritDamageFactor")
    if inheritDamageFactor then
      projectileParameters.power = projectile.power() * inheritDamageFactor
    end

    world.spawnProjectile(projectileType, mcontroller.position(), projectile.sourceEntity(), {math.cos(rotation), math.sin(rotation)}, false, projectileParameters)
    local explosionAction = projectile.getParameter("explosionAction")
    if explosionAction then
      projectile.processAction(explosionAction)
    end
  end
end
