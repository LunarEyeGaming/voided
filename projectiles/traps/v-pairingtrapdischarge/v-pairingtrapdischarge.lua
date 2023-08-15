require "/scripts/vec2.lua"
require "/scripts/util.lua"

--[[
  Modified version of the homingprojectile.lua script that homes onto pairing trap objects. Also, fields of "self" are
  replaced with local variables for microscopic improvements in performance.
]]

local homingDistance
local rotationRate
local trackingLimit
local excludedEntities
local sourceEntity
local queryParameters
local activationRadius

function init()
  homingDistance = config.getParameter("homingDistance", 20)
  rotationRate = config.getParameter("rotationRate")
  trackingLimit = config.getParameter("trackingLimit")
  excludedEntities = config.getParameter("excludedEntities")
  sourceEntity = projectile.sourceEntity()
  queryParameters = {
    withoutEntityId = sourceEntity,
    includedTypes = {"object"},
    order = "nearest", 
    callScript = "pairableNoCollision"
  }
  activationRadius = config.getParameter("activationRadius")

  local ttlVariance = config.getParameter("timeToLiveVariance")
  if ttlVariance then
    projectile.setTimeToLive(projectile.timeToLive() + sb.nrand(ttlVariance))
  end
end

function update(dt)
  -- Prevent this projectile from going into dungeons
  if world.isTileProtected(mcontroller.position()) then
    projectile.die()  
  end

  local pos = mcontroller.position()
  local candidates = world.entityQuery(pos, homingDistance, queryParameters)

  if #candidates == 0 then return end

  local vel = mcontroller.velocity()
  local angle = vec2.angle(vel)

  -- Because there are no conditions for candidates, pick the one closest to the projectile (the first one).
  local canPos = world.entityPosition(candidates[1])
  
  if world.magnitude(canPos, pos) < activationRadius then
    world.sendEntityMessage(candidates[1], "trigger")
    projectile.die()
  end
  
  local toTarget = world.distance(canPos, pos)
  local toTargetAngle = util.angleDiff(angle, vec2.angle(toTarget))

  if math.abs(toTargetAngle) > trackingLimit then
    return
  end

  local rotateAngle = math.max(dt * -rotationRate, math.min(toTargetAngle, dt * rotationRate))

  vel = vec2.rotate(vel, rotateAngle)
  mcontroller.setVelocity(vel)

  mcontroller.setRotation(math.atan(vel[2], vel[1]))
end