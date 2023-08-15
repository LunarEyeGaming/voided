require "/scripts/util.lua"
require "/scripts/vec2.lua"

--[[
  A variant of the railtramstop.lua script that wirelessly propagates a tram call signal to nearby tram stops and other
  signal relays instead of connected tram stops. The object is not intended to have any sort of animation and is not
  intended to be passed over by a tram. The object is intended to solve a problem where a tram system is built across
  multiple dungeon parts and the tram stop nodes need to be connected together (wires won't work because the dungeon
  builder tries to connect them while building *each piece* and not when the dungeon has been fully built). It is best
  for the person making the dungeon parts to place these near part connectors (and change the propagateRange so that it
  reaches nearby signal relays if necessary).
]]

local propagateRange

function init()
  message.setHandler("railRiderPresent", function()
      stopWaiting()
    end)

  storage.waiting = storage.waiting or false
  storage.active = storage.active or false
  
  propagateRange = config.getParameter("propagateRange")
end

function nodePosition()
  return util.tileCenter(entity.position())
end

function die()
  propagateCancel()
end

function propagateActivate(summonPosition)
  if not storage.active and not vec2.eq(summonPosition, nodePosition()) then
    -- sb.logInfo("%s activated", entity.id())
    storage.active = true
    storage.waiting = false
    callNearbyAndConnected("propagateActivate", summonPosition)
  end
end

function propagateCancel()
  if storage.active or storage.waiting then
    -- sb.logInfo("%s deactivated", entity.id())
    storage.active = false
    storage.waiting = false
    callNearbyAndConnected("propagateCancel")
  end
end

function callNearbyAndConnected(callFunction, callData)
  local queried = world.objectQuery(nodePosition(), propagateRange, {withoutEntityId = entity.id()})

  for _, entityId in ipairs(queried) do
    world.callScriptedEntity(entityId, callFunction, callData)
  end
  
  for entityId, _ in pairs(object.getInputNodeIds(0)) do
    world.callScriptedEntity(entityId, callFunction, callData)
  end
end