require "/scripts/vec2.lua"

local isFresh
local orbitRadius
local orbitPeriod
local masterId
local startAngle
local orbitAngle

local projectileType
local projectileConfig
local targetId

function init()
  orbitRadius = config.getParameter("orbitRadius")
  orbitPeriod = config.getParameter("orbitPeriod")
  masterId = projectile.sourceEntity()
  startAngle = config.getParameter("startAngle", 0)
  orbitAngle = startAngle

  projectileType = config.getParameter("firedProjectile")
  projectileConfig = config.getParameter("firedProjectileConfig")
  projectileConfig.power = projectileConfig.power or projectile.power()
  projectileConfig.powerMultiplier = projectileConfig.powerMultiplier or projectile.powerMultiplier()

  message.setHandler("fresh", function()
    isFresh = true
  end)

  message.setHandler("kill", function(_, _, id)
    targetId = id
    projectile.die()
  end)

  message.setHandler("reset", function(_, _, angle)
    orbitAngle = angle
  end)
end

function update(dt)
  mcontroller.setVelocity({0, 0})

  if not isFresh then
    projectile.die()
  end
  if not masterId or not world.entityExists(masterId) then return end

  if projectile.timeToLive() > 0 then
    projectile.setTimeToLive(0.5)
  end

  orbitAngle = orbitAngle + (dt * 2 * math.pi / orbitPeriod)
  local orbitOffset = vec2.mul({math.cos(orbitAngle), math.sin(orbitAngle)}, orbitRadius)
  local orbitPosition = vec2.add(world.entityPosition(masterId), orbitOffset)
  mcontroller.setPosition(orbitPosition)
end

function destroy()
  local selfPosition = mcontroller.position()
  if projectile.sourceEntity() and world.entityExists(projectile.sourceEntity())
    and targetId and world.entityExists(targetId) then
    world.spawnProjectile(projectileType, selfPosition, projectile.sourceEntity(), world.distance(world.entityPosition(targetId), selfPosition), false, projectileConfig)
    local foundTargetAction = config.getParameter("foundTargetAction")
    if next(foundTargetAction) ~= nil then
      projectile.processAction(foundTargetAction)
    end
  end
end
