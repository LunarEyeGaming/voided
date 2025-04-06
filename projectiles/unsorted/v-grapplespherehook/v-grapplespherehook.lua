require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local ownerId
local launchDistance
local breakOnSlipperyCollision
local startPos
local isDead

function init()
  ownerId = projectile.sourceEntity()
  launchDistance = config.getParameter("launchDistance")
  breakOnSlipperyCollision = config.getParameter("breakOnSlipperyCollision")
  startPos = mcontroller.position()
  isDead = false
end

function update(dt)
  if ownerId and world.entityExists(ownerId) then
    -- Keep alive if the projectile isn't supposed to die yet.
    -- if projectile.timeToLive() > 0.5 then
    --   projectile.setTimeToLive(1.0)
    -- end

    if world.magnitude(mcontroller.position(), startPos) > launchDistance then
      kill()
    end

    if breakOnSlipperyCollision and not mcontroller.stickingDirection() and mcontroller.isColliding() then
      kill()
    end
  end
end

function anchored()
  return mcontroller.stickingDirection()
end

function kill()
  isDead = true
end

function shouldDestroy()
  -- return isDead or projectile.timeToLive() <= 0
  return isDead
end