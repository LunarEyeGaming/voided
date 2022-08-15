require "/scripts/vec2.lua"

local ownerId
local breakOnSlipperyCollision
local isDead

function init()
  ownerId = projectile.sourceEntity()
  breakOnSlipperyCollision = config.getParameter("breakOnSlipperyCollision")
  isDead = false
end

function update(dt)
  if ownerId and world.entityExists(ownerId) then
    if mcontroller.stickingDirection() then
      projectile.setTimeToLive(0.5)
    elseif breakOnSlipperyCollision and mcontroller.isColliding() then
      kill()
    end
  else
    kill()
  end
end

function anchored()
  return mcontroller.stickingDirection()
end

function kill()
  isDead = true
end

function shouldDestroy()
  return isDead or projectile.timeToLive() <= 0
end
