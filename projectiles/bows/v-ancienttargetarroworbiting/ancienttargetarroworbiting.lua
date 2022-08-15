require "/scripts/vec2.lua"

local orbitRadius
local orbitPeriod
local orbitControlForce
local masterId
local startAngle
local orbitAngle

local projectileType
local projectileConfig
local targetId

function init()
  orbitRadius = config.getParameter("orbitRadius")
  orbitPeriod = config.getParameter("orbitPeriod")
  orbitControlForce = config.getParameter("orbitControlForce")
  masterId = config.getParameter("masterId")
  startAngle = config.getParameter("startAngle", 0)
  orbitAngle = startAngle

  projectileType = config.getParameter("firedProjectile")
  projectileConfig = config.getParameter("firedProjectileConfig")
  projectileConfig.power = projectileConfig.power or projectile.power()
  projectileConfig.powerMultiplier = projectileConfig.powerMultiplier or projectile.powerMultiplier()

  message.setHandler("kill", function(_, _, id)
    targetId = id
    projectile.die()
  end)
  
  mcontroller.setVelocity({0, 0})
end

function update(dt)
  if not masterId or not world.entityExists(masterId) then return end

  if projectile.timeToLive() > 0 then
    projectile.setTimeToLive(0.5)
  end

  orbitAngle = orbitAngle + (dt * 2 * math.pi / orbitPeriod)
  local orbitOffset = vec2.mul({math.cos(orbitAngle), math.sin(orbitAngle)}, orbitRadius)
  local orbitPosition = vec2.add(world.entityPosition(masterId), orbitOffset)
  local toOrbitVelocity = vec2.mul(vec2.norm(world.distance(orbitPosition, mcontroller.position())), projectile.getParameter("speed"))
  mcontroller.approachVelocity(toOrbitVelocity, orbitControlForce)
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
