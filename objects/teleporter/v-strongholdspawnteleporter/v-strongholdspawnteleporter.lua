require "/scripts/util.lua"
require "/scripts/vec2.lua"

local teleportStatusEffect
local chainsConfig
local beamDelay
local deactivationDelay
local teleporterState

function init()
  teleportStatusEffect = config.getParameter("teleportStatusEffect", "v-ancientstrongholdteleport")
  chainsConfig = config.getParameter("chains")
  beamDelay = config.getParameter("beamDelay", 0.5)
  deactivationDelay = config.getParameter("deactivationDelay", 0.5)
  object.setInteractive(true)
  
  teleporterState = FSM:new()
  teleporterState:set(noop)
end

function update()
  teleporterState:update()
end

function teleport(sourceId)
  animator.setAnimationState("teleporter", "activate")
  
  util.wait(beamDelay)

  world.sendEntityMessage(sourceId, "applyStatusEffect", teleportStatusEffect)
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

function onInteraction(args)
  teleporterState:set(teleport, args.sourceId)
end