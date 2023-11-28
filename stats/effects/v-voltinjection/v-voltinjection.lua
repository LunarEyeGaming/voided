local shockRadius
local explosionPower
local boltPower
local boltSpeed

local triggeredOnDeath

function init()
  effect.setParentDirectives("fade=4a4ab5=0.4")

  shockRadius = config.getParameter("shockRadius")
  explosionPower = config.getParameter("explosionPower")
  boltPower = config.getParameter("boltPower")
  boltSpeed = config.getParameter("boltSpeed")
  
  triggeredOnDeath = false
end

function update(dt)
  if not status.resourcePositive("health") then
    onDeath()
  end
end

function onDeath()
  if triggeredOnDeath then
    return 
  end

  local sourceEntityId = effect.sourceEntity() or entity.id()
  local sourceDamageTeam = world.entityDamageTeam(sourceEntityId)

  world.spawnProjectile("electricplasmaexplosion", mcontroller.position(), entity.id(), {0, 0}, false, {
    damageTeam = sourceDamageTeam, 
    power = explosionPower
  })
  local queried = world.entityQuery(mcontroller.position(), shockRadius, {includedTypes = {"creature"}})
  for _, entityId in ipairs(queried) do
    if world.entityExists(entityId) then
      local aimVector = world.distance(world.entityPosition(entityId), mcontroller.position())
      if world.entityCanDamage(sourceEntityId, entityId) and not world.lineCollision(world.entityPosition(entityId), 
          mcontroller.position()) then
        world.spawnProjectile("teslaboltsmall", mcontroller.position(), entity.id(), aimVector, false, {
          power = boltPower,
          speed = boltSpeed,
          damageTeam = sourceDamageTeam
        })
      end
    end
  end
  
  triggeredOnDeath = true
end