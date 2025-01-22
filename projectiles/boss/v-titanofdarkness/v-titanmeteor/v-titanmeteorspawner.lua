require "/scripts/vec2.lua"

local spawnDelay

local fuzzAngle
local meteorProjectile
local meteorProjectileSpeed
local meteorProjectileParameters
local meteorDamageFactor
local teleProjectile
local teleProjectileParameters
local maxGroundDistance

local spawnTimer
local spawnDirection

function init()
  spawnDelay = config.getParameter("spawnDelay", 0)

  fuzzAngle = config.getParameter("fuzzAngle", 0) * math.pi / 180  -- Convert to radians
  meteorProjectile = config.getParameter("meteorProjectile")
  meteorProjectileSpeed = config.getParameter("meteorProjectileSpeed")
  meteorProjectileParameters = config.getParameter("meteorProjectileParameters", {})
  meteorProjectileParameters.speed = meteorProjectileSpeed
  meteorDamageFactor = config.getParameter("meteorDamageFactor")
  teleProjectile = config.getParameter("teleProjectile")
  teleProjectileParameters = config.getParameter("teleProjectileParameters", {})
  maxGroundDistance = config.getParameter("maxGroundDistance")

  if meteorDamageFactor then
    meteorProjectileParameters.power = projectile.power() * meteorDamageFactor
    meteorProjectileParameters.powerMultiplier = projectile.powerMultiplier()
  end

  spawnTimer = spawnDelay
  -- Straight downwards, plus a random angle between -fuzzAngle and +fuzzAngle.
  spawnDirection = vec2.rotate({0, -1}, math.random() * 2 * fuzzAngle - fuzzAngle)

  mcontroller.setRotation(vec2.angle(spawnDirection))  -- Point in spawnDirection
end

function update(dt)
  -- If the meteor has not spawned yet (signified by the spawnTimer still being defined)...
  if spawnTimer then
    spawnTimer = spawnTimer - dt

    -- If the timer has run out...
    if spawnTimer <= 0 then
      spawnMeteor()  -- Spawn the meteor.

      spawnTimer = nil  -- Mark meteor as spawned.
    end
  end
end

function spawnMeteor()

  -- Compute end position of collision test.
  local endPos = vec2.add(mcontroller.position(), vec2.mul(spawnDirection, maxGroundDistance))
  -- Determine place to spawn telegraph.
  local telegraphPos = world.lineCollision(mcontroller.position(), endPos)

  -- If no collision occurred...
  if not telegraphPos then
    return  -- Abort
  end

  -- Set time to live based on how long it would take for the meteor to land at the collision point.
  teleProjectileParameters.timeToLive = world.magnitude(mcontroller.position(), telegraphPos) / meteorProjectileSpeed

  -- Spawn telegraph projectile
  world.spawnProjectile(teleProjectile, telegraphPos, projectile.sourceEntity(), spawnDirection, false,
  teleProjectileParameters)

  -- Spawn meteor projectile.
  world.spawnProjectile(meteorProjectile, mcontroller.position(), projectile.sourceEntity(), spawnDirection, false,
  meteorProjectileParameters)
end