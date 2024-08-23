require "/scripts/v-world.lua"

local queryRadius
local detonateProjectileType
local detonateProjectileParameters
local detonateDamageFactor

local sentMessage

function init()
  queryRadius = config.getParameter("queryRadius")
  detonateProjectileType = config.getParameter("detonateProjectileType")
  detonateProjectileParameters = config.getParameter("detonateProjectileParameters")
  detonateDamageFactor = config.getParameter("detonateDamageFactor", 1.0)

  detonateProjectileParameters.power = detonateProjectileParameters.power or projectile.power() * detonateDamageFactor
  detonateProjectileParameters.powerMultiplier = projectile.powerMultiplier()

  message.setHandler("kill", projectile.die)

  sentMessage = false
end

function update(dt)
  -- Necessary to send the registerProjectile message here instead of init.
  if not sentMessage then
    vWorld.sendEntityMessage(projectile.sourceEntity(), "registerProjectile", entity.id())
    sentMessage = true
  end

  local queried = world.entityQuery(mcontroller.position(), queryRadius, {includedTypes = {"creature"}})

  -- Go through each queried entity...
  for _, entityId in ipairs(queried) do
    -- If the source entity can damage the queried entity...
    if world.entityCanDamage(projectile.sourceEntity(), entityId) then
      -- Spawn a projectile at that entity's position...
      world.spawnProjectile(detonateProjectileType, world.entityPosition(entityId), projectile.sourceEntity(), {1, 0},
        false, detonateProjectileParameters)
      -- ...and die
      projectile.die()
      -- Return so that no more projectiles are spawned
      return
    end
  end
end