function destroy()
  -- Get parameters
  local lightningRodType = config.getParameter("lightningRodType")
  local lightningRodRedirectRadius = config.getParameter("lightningRodRedirectRadius")
  local projectileType = config.getParameter("projectileType")

  -- Query objects within a `lightningRodRedirectRadius` with name `lightningRodType`.
  local queried = world.objectQuery(mcontroller.position(), lightningRodRedirectRadius, {order = "nearest",
      name = lightningRodType})

  local targetPos

  -- If at least one object was found...
  if #queried > 0 then
    targetPos = world.entityPosition(queried[1])
  else
    targetPos = mcontroller.position()
  end

  -- Spawn the projectile
  world.spawnProjectile(projectileType, targetPos, projectile.sourceEntity(), {1, 0}, false, {power = projectile.power(), damageTeam = entity.damageTeam()})
end