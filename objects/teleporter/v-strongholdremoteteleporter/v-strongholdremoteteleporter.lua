--[[
  A script that animates the teleporter for when someone uses a v-strongholdspawnteleporter object to teleport to the
  v-strongholdremoteteleporter. When one player teleports, laser beams are rendered coming out of the teleporter
  sockets and toward the player who teleported. Then, the sockets are deactivated. If multiple players teleport at the 
  same time, the sockets do not deactivate until all players are finished teleporting.
]]

require "/scripts/util.lua"
require "/scripts/vec2.lua"

local chainsConfig
local deactivationDelay
local numTeleportingPlayers
local teleportThreads

function init()
  chainsConfig = config.getParameter("chains")
  deactivationDelay = config.getParameter("deactivationDelay", 0.5)
  numTeleportingPlayers = 0
  teleportThreads = {}
  
  message.setHandler("preactivate", function()
    -- If this is the first player teleporting in a potential sequence...
    if numTeleportingPlayers == 0 then
      animator.setAnimationState("teleporter", "activate")
    end
    
    -- Increase the counter for the number of teleporting players.
    numTeleportingPlayers = numTeleportingPlayers + 1
  end)
  
  message.setHandler("activate", function(_, _, sourceId)
    local thread = coroutine.create(teleport)
    
    local status, result = coroutine.resume(thread, sourceId)  -- Start thread
    
    -- If an error occurred...
    if not status then
      error(result)
    end
    
    table.insert(teleportThreads, {thread = thread, args = {sourceId}})
  end)
end

function update()
  updateThreads()
end

-- Plays the animation for the teleporter.
function teleport(sourceId)
  -- Render chains
  local pos = object.position()
  local chains = {}
  for _, offset in ipairs(chainsConfig.startOffsets) do
    local chain = copy(chainsConfig.properties)
    
    chain.startPosition = vec2.add(pos, offset)
    chain.endPosition = world.entityPosition(sourceId)
    
    table.insert(chains, chain)
  end
  object.setAnimationParameter("chains", chains)
  
  util.wait(chainsConfig.activeDuration)
  
  -- Remove chains
  object.setAnimationParameter("chains", {})
  
  -- Wait for a little bit
  util.wait(deactivationDelay)

  -- Decrement counter
  numTeleportingPlayers = numTeleportingPlayers - 1

  -- If this is the last player to teleport...
  if numTeleportingPlayers == 0 then
    animator.setAnimationState("teleporter", "deactivate")
  end
end

-- Goes through all the active threads and updates them, also removing each one that is now inactive.
function updateThreads()
  local i = 1

  -- Walk through the teleportThreads list.
  while i <= #teleportThreads do
    local thread = teleportThreads[i]

    -- If the coroutine has not finished running...
    if coroutine.status(thread.thread) ~= "dead" then
      local status, result = coroutine.resume(thread.thread, table.unpack(thread.args))
      
      -- If an error occurred...
      if not status then
        error(result)  -- Report the error
      end

      i = i + 1  -- Placed here to avoid skipping consecutive items that need to be deleted.
    else
      table.remove(teleportThreads, i)
    end
  end
end