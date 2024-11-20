--[[
  A simple script that outputs a signal for a specific amount of time whenever it receives an electrical current.
]]

require "/scripts/vec2.lua"

local projectileType
local projectileDirection
local inaccuracy
local projectilePosition
local cooldownTime

local timer

function init()
  projectileType = config.getParameter("projectile")
  projectileDirection = config.getParameter("projectileDirection", {1, 0})
  projectilePosition = object.toAbsolutePosition(config.getParameter("projectilePosition", {0, 0}))
  projectileConfig = config.getParameter("projectileConfig", {})
  inaccuracy = config.getParameter("inaccuracy", 0)

  cooldownTime = config.getParameter("cooldownTime", 1.0)

  timer = nil
end

function update(dt)
  -- If the ability is on cooldown...
  if timer then
    -- Decrement timer
    timer = timer - dt
    -- If the cooldown timer has run out...
    if timer <= 0 then
      -- Clear cooldown status
      timer = nil
    end
  end
end

function shoot()
  animator.playSound("shoot")
  local aimVector = vec2.rotate(projectileDirection, sb.nrand(inaccuracy, 0))
  world.spawnProjectile(projectileType, projectilePosition, entity.id(), aimVector, false, projectileConfig)
end

function v_onShockwaveReceived()
  -- Fire projectile if not on cooldown.
  if not timer then
    shoot()
    timer = cooldownTime
  end

  return true
end