require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local spawnInterval

local fuzzAngle
local meteorProjectile
local meteorProjectileSpeed
local meteorProjectileParameters
local meteorDamageFactor
local spawnHeight

local spawnTimer

function init()
  oldInit()

  spawnInterval = config.getParameter("spawnInterval", 0)

  fuzzAngle = config.getParameter("fuzzAngle", 0) * math.pi / 180  -- Convert to radians
  meteorProjectile = config.getParameter("meteorProjectile")
  meteorProjectileSpeed = config.getParameter("meteorProjectileSpeed")
  meteorProjectileParameters = config.getParameter("meteorProjectileParameters", {})
  meteorProjectileParameters.speed = meteorProjectileSpeed
  meteorDamageFactor = config.getParameter("meteorDamageFactor")
  spawnHeight = config.getParameter("spawnHeight")

  if meteorDamageFactor then
    meteorProjectileParameters.power = projectile.power() * meteorDamageFactor
    meteorProjectileParameters.powerMultiplier = projectile.powerMultiplier()
  end

  spawnTimer = spawnInterval
end

function update(dt)
  oldUpdate(dt)

  spawnTimer = spawnTimer - dt

  -- If the timer has run out...
  if spawnTimer <= 0 then
    spawnMeteor()  -- Spawn the meteor.

    spawnTimer = spawnInterval
  end
end

function spawnMeteor()
  -- Straight upwards, plus a random angle between -fuzzAngle and +fuzzAngle.
  local spawnDirection = vec2.rotate({0, 1}, math.random() * 2 * fuzzAngle - fuzzAngle)
  -- Compute spawn position
  local spawnPos = vec2.add(mcontroller.position(), vec2.mul(spawnDirection, spawnHeight))
  local aimDirection = vec2.rotate(spawnDirection, math.pi)

  meteorProjectileParameters.targetPos = mcontroller.position()

  -- Spawn meteor projectile.
  world.spawnProjectile(meteorProjectile, spawnPos, projectile.sourceEntity(), aimDirection, false,
  meteorProjectileParameters)
end