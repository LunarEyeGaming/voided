require "/scripts/stagehandutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

--[[
  A stagehand that uses a projectile as a set of barriers to create a simple arena from nothing. It also keeps players
  in the arena by forcing them to be teleported back into it if they somehow leave. It is activated using the 
  v-activateArena message and deactivated using the v-deactivateArena message. The projectile must handle the "kill"
  entity message for arena deactivation to work properly, and this script assumes that the projectile otherwise exists
  indefinitely. The barrier dimensions do not scale with the size of the stagehand. The projectile is spawned at the
  stagehand's position.
  
  Teleportation requires setup of a v-teleport message handler for the player entity and will teleport the player to
  their previous position if they exit the arena. A projectile is also spawned at the player's old position and their
  position outside of the arena for animation purposes.
]]

local barrierProjectileType
local teleportProjectileType

local barrierId  -- The ID of the spawned barrier

local barrierActive

local inArenaPlayerPositions

function init()
  barrierProjectileType = config.getParameter("barrierProjectileType")
  teleportProjectileType = config.getParameter("teleportProjectileType")
  
  barrierActive = false

  barrierId = nil

  message.setHandler("v-activateArena", activateArena)
  message.setHandler("v-deactivateArena", deactivateArena)
  
  inArenaPlayerPositions = {}
end

--[[
  If the barrier is active, teleports players who were previously in the arena and exited the arena back in. Also 
  queries all players who are currently in the arena and removes players who died.
]]
function update(dt)
  if barrierActive then
    local queried = broadcastAreaQuery({includedTypes = {"player"}})
  
    -- Add positions of all queried players who were not already added.
    for _, playerId in ipairs(queried) do
      if not inArenaPlayerPositions[playerId] then
        inArenaPlayerPositions[playerId] = world.entityPosition(playerId)
      end
    end
    
    -- For all tracked players...
    for playerId, pos in pairs(inArenaPlayerPositions) do
      -- If the player no longer exists...
      if not world.entityExists(playerId) then
        inArenaPlayerPositions[playerId] = nil
      else
        -- If the player is no longer in the arena because they were not captured in the initial query...
        if not contains(queried, playerId) then
          world.sendEntityMessage(playerId, "v-teleport", pos)

          world.spawnProjectile(teleportProjectileType, pos)
          world.spawnProjectile(teleportProjectileType, world.entityPosition(playerId))
          -- Forget the player to prevent spamming of messages in the event that the player's client lags.
          inArenaPlayerPositions[playerId] = nil
        else
          inArenaPlayerPositions[playerId] = world.entityPosition(playerId)
        end
      end
    end
  end
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