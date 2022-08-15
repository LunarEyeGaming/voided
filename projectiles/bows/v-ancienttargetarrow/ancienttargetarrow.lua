local targetRadius
local projectileType
local projectileConfig
local queryDelta
local queryStep

function init()
  targetRadius = config.getParameter("targetRadius")
  projectileType = config.getParameter("firedProjectile")
  projectileConfig = config.getParameter("firedProjectileConfig")
  projectileConfig.power = projectileConfig.power or projectile.power()
  projectileConfig.powerMultiplier = projectileConfig.powerMultiplier or projectile.powerMultiplier()
  queryDelta = 10
  queryStep = queryDelta
end

function update(dt)
  queryStep = math.max(0, queryStep - 1)
  if queryStep == 0 then
    local near = world.entityQuery(mcontroller.position(), targetRadius, { includedTypes = {"monster", "npc"} })
    for _,entityId in pairs(near) do
      if entity.isValidTarget(entityId) then
        if not targetId then
          targetId = entityId
        end
        projectile.die()
      end
    end
    queryStep = queryDelta
  end
end

function destroy()
  local selfPosition = mcontroller.position()
  if projectile.sourceEntity() and world.entityExists(projectile.sourceEntity()) and targetId then
    world.spawnProjectile(projectileType, selfPosition, projectile.sourceEntity(), world.distance(world.entityPosition(targetId), selfPosition), false, projectileConfig)
    local foundTargetAction = config.getParameter("foundTargetAction", {})
    if next(foundTargetAction) ~= nil then
      projectile.processAction(foundTargetAction)
    end
  end
end
