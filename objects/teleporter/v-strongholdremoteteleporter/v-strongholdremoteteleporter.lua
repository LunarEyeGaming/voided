require "/scripts/util.lua"
require "/scripts/vec2.lua"

local chainsConfig
local deactivationDelay
local teleporterState

function init()
  chainsConfig = config.getParameter("chains")
  deactivationDelay = config.getParameter("deactivationDelay", 0.5)
  
  message.setHandler("preactivate", function()
    animator.setAnimationState("teleporter", "activate")
  end)
  
  message.setHandler("activate", function(_, _, sourceId)
    teleporterState:set(teleport, sourceId)
  end)
  
  teleporterState = FSM:new()
  teleporterState:set(noop)
end

function update()
  teleporterState:update()
end

function teleport(sourceId)
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
  
  object.setAnimationParameter("chains", {})
  util.wait(deactivationDelay)
  animator.setAnimationState("teleporter", "deactivate")

  teleporterState:set(noop)
end

function noop()
  while true do
    coroutine.yield()
  end
end