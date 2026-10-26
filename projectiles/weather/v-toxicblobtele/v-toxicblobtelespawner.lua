require "/scripts/rect.lua"
require "/scripts/vec2.lua"

local teleProjectileType
local teleProjectileParameters
local destroyProjectileType
local destroyProjectileParameters

local teleSpawnInterval
local teleSpawnOffsetRange

local velocity

local teleSpawnTimer

function init()
  teleProjectileType = config.getParameter("teleProjectileType")
  teleProjectileParameters = config.getParameter("teleProjectileParameters", {})
  destroyProjectileType = config.getParameter("destroyProjectileType")
  destroyProjectileParameters = config.getParameter("destroyProjectileParameters", {})

  teleSpawnInterval = config.getParameter("teleSpawnInterval")
  teleSpawnOffsetRange = config.getParameter("teleSpawnOffsetRange")

  velocity = mcontroller.velocity()

  mcontroller.setVelocity({0, 0})

  teleSpawnTimer = teleSpawnInterval
end

function update(dt)
  teleSpawnTimer = teleSpawnTimer - dt

  if teleSpawnTimer <= 0 then
    local position = vec2.add(rect.randomPoint(teleSpawnOffsetRange), mcontroller.position())

    world.spawnProjectile(teleProjectileType, position, projectile.sourceEntity(), velocity, false, sb.jsonMerge({
      speed = vec2.mag(velocity)
    }, teleProjectileParameters))

    teleSpawnTimer = teleSpawnInterval
  end
end

function destroy()
  world.spawnProjectile(destroyProjectileType, mcontroller.position(), projectile.sourceEntity(), velocity, false, sb.jsonMerge({
    speed = vec2.mag(velocity),
    power = projectile.power(),
    powerMultiplier = projectile.powerMultiplier()
  }, destroyProjectileParameters))
end