require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

--[[
  Flies around in random directions while changing size randomly. Also fires projectiles in random directions. Contact
  damage size is based on visual size. Used by the v-balllightning monster.
]]

local maxSpeed
local controlForce
local velocityChangeTimeRange
local sizeRange

local projectileFireTime
local projectileType
local projectileParameters

local sizeChangeTime

local sizeTimer
local velocityTimer
local projectileFireTimer

local previousTargetSize
local currentSize

local targetSize
local velocity

function init()
  maxSpeed = config.getParameter("maxSpeed")
  controlForce = config.getParameter("controlForce")
  velocityChangeTimeRange = config.getParameter("velocityChangeTimeRange")
  sizeChangeTimeRange = config.getParameter("sizeChangeTimeRange")
  sizeRange = config.getParameter("sizeRange")

  projectileFireTime = config.getParameter("projectileFireTime")
  projectileType = config.getParameter("projectileType")
  projectileParameters = config.getParameter("projectileParameters", {})
  projectileParameters.power = scaleDamage(projectileParameters.power)
  
  sizeChangeTime = util.randomInRange(sizeChangeTimeRange)

  velocityTimer = util.randomInRange(velocityChangeTimeRange)
  projectileFireTimer = projectileFireTime
  sizeTimer = sizeChangeTime

  previousTargetSize = 1
  currentSize = previousTargetSize

  targetSize = util.randomInRange(sizeRange)
  velocity = randomPointInCircle(maxSpeed)
  -- velocity and targetSize get initialized before they are used b/c sizeTimer and velocityTimer both are 0
  
  monster.setDamageBar("None")
end

function update(dt)
  -- Stop it from invading dungeons.
  -- If the current position is protected, then die instantly.
  if world.isTileProtected(mcontroller.position()) then
    status.setResourcePercentage("health", 0.0)
  end

  fireProjectile(dt)
  updateSize(dt)
  updateVelocity(dt)
end

--[[
  Fires a projectile in a random direction every <projectileFireTime> seconds. Call on every tick.
]]
function fireProjectile(dt)
  projectileFireTimer = projectileFireTimer - dt

  if projectileFireTimer < 0 then
    world.spawnProjectile(projectileType, mcontroller.position(), entity.id(), 
        randomPointInCircle(1), false, projectileParameters)
    projectileFireTimer = projectileFireTime
  end
end

--[[
  Updates the size of the monster (both visual and contact damage). The size linearly grows and shrinks to random
  amounts. Call on every tick.
]]
function updateSize(dt)
  sizeTimer = sizeTimer - dt
  
  if sizeTimer < 0 then
    sizeChangeTime = util.randomInRange(sizeChangeTimeRange)
    sizeTimer = sizeChangeTime
    previousTargetSize = targetSize
    targetSize = util.randomInRange(sizeRange)
  end
  
  currentSize = util.lerp(sizeTimer / sizeChangeTime, targetSize, previousTargetSize)

  animator.resetTransformationGroup("body")
  animator.scaleTransformationGroup("body", currentSize)
  
  local touchDamageSource = config.getParameter("touchDamage")
  touchDamageSource.damage = scaleDamage(touchDamageSource.damage)
  touchDamageSource.poly = poly.scale(touchDamageSource.poly, currentSize)
  
  monster.setDamageSources({touchDamageSource})
end

--[[
  Periodically sets a random velocity (interval is random) and approaches that velocity. Call on every tick.
]]
function updateVelocity(dt)
  velocityTimer = velocityTimer - dt
  
  if velocityTimer < 0 then
    velocity = randomPointInCircle(maxSpeed, {0, 0})
    velocityTimer = util.randomInRange(velocityChangeTimeRange)
  end
  
  mcontroller.controlApproachVelocity(velocity, controlForce)
end

--[[
  Returns a random point inside a circle with the given center and radius.
  param number radius: the radius of the circle
  param Vec2 center (optional): the center of the circle. Defaults to {0, 0} if unspecified
  returns Vec2: a random point in the circle
]]
-- TODO: move to /scripts/voidedcircle.lua
function randomPointInCircle(radius, center)
  if not center then
    center = {0, 0}
  end
  local offset = vec2.withAngle(util.randomInRange({0, 2 * math.pi}), radius)
  
  return vec2.add(center, offset)
end

--[[
  Returns the damage scaled by the monster's level according to the monsterLevelPowerMultiplier function.
  
  param number damage (optional): the damage to scale. Defaults to 10 if unspecified
  returns number: the damage scaled by the monster's level
]]
-- TODO: move to /scripts/voidedmonsterutil.lua
function scaleDamage(damage)
  return (damage or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
end