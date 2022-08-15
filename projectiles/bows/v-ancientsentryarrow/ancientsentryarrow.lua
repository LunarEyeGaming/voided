require "/scripts/util.lua"

local fireRadius
local fireTime
local orbiterCount
local orbiterProjectile
local orbiterProjectileConfig
local orbiterDamageFactor
local orbiters
local fireTimer

function init()
  fireRadius = config.getParameter("fireRadius")
  fireTime = config.getParameter("fireTime")
  orbiterCount = config.getParameter("orbiterCount")
  orbiterProjectile = config.getParameter("orbiterProjectile")
  orbiterProjectileConfig = config.getParameter("orbiterProjectileConfig", {})
  orbiterDamageFactor = config.getParameter("orbiterDamageFactor", 1.0)
  orbiterProjectileConfig.power = (orbiterProjectileConfig.power or projectile.power()) * orbiterDamageFactor
  orbiterProjectileConfig.powerMultiplier = orbiterProjectileConfig.powerMultiplier or projectile.powerMultiplier()
  orbiterProjectileConfig.masterId = entity.id()

  orbiters = {}
  for i = 1, orbiterCount do
    local orbiterParams = copy(orbiterProjectileConfig)
    orbiterParams.startAngle = 2 * math.pi * i / orbiterCount
    local orbiter = world.spawnProjectile(orbiterProjectile, mcontroller.position(), projectile.sourceEntity(), {0, 0}, false, orbiterParams)
    table.insert(orbiters, orbiter)
  end
  fireTimer = fireTime
  message.setHandler("kill", projectile.die)
end

function update(dt)
  if #orbiters == 0 then
    projectile.die()
  end

  fireTimer = math.max(0, fireTimer - dt)
  local near = world.entityQuery(mcontroller.position(), fireRadius, { includedTypes = {"monster", "npc"}, order = "nearest" })
  
  near = util.filter(near, function(x)
    return entity.isValidTarget(x)
  end)
  
  if #near > 0 and #orbiters > 0 and fireTimer == 0 then
    local orbiterNum = math.random(1, #orbiters)
    local orbiter = table.remove(orbiters, orbiterNum)
    if world.entityExists(orbiter) and not world.lineTileCollision(mcontroller.position(), world.entityPosition(near[1])) then
      world.sendEntityMessage(orbiter, "kill", near[1])
    else
      table.insert(orbiters, orbiter)
    end
    fireTimer = fireTime
  end
end

function destroy()
  for _, orbiter in pairs(orbiters) do
    world.sendEntityMessage(orbiter, "kill")
  end
end
