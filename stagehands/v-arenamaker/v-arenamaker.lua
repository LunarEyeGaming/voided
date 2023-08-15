require "/scripts/rect.lua"
require "/scripts/vec2.lua"

--[[
  A stagehand that uses a projectile as a set of barriers to create a simple arena from nothing. It is activated using
  the v-activateArena message and deactivated using the v-deactivateArena message. The projectile must handle the "kill"
  entity message for arena deactivation to work properly, and this script assumes that the projectile otherwise exists
  indefinitely. The barrier dimensions do not scale with the size of the stagehand. The projectile is spawned at the
  stagehand's position.
]]

local barrierProjectileType

local barrierId  -- The ID of the spawned barrier

local barrierActive

function init()
  barrierProjectileType = config.getParameter("barrierProjectileType")
  
  barrierActive = false

  barrierId = nil

  message.setHandler("v-activateArena", activateArena)
  message.setHandler("v-deactivateArena", deactivateArena)
end

--[[
  Spawns the barrier projectile at the stagehand's position and sets barrierId to the resulting ID. Does nothing if the
  barrier is already active.
]]
function activateArena()
  if not barrierActive then
    barrierId = world.spawnProjectile(barrierProjectileType, stagehand.position(), entity.id(), {1, 0})

    barrierActive = true
  end
end

--[[
  Kills the spawned barrier projectile and sets barrierId to nil. Does nothing if the barrier is inactive.
]]
function deactivateArena()
  if barrierActive then
    world.sendEntityMessage(barrierId, "kill")
    
    barrierId = nil

    barrierActive = false
  end
end