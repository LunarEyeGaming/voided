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
  
  -- Create new FSM
  teleporterState = FSM:new()
  teleporterState:set(noop)
end

function update()
  -- Update the teleporter coroutine (or it won't run at all)
  teleporterState:update()
end

-- Plays the animation for the teleporter.
function teleport(sourceId)
  object.setInteractive(false)

  -- Turn on lights
  animator.setAnimationState("teleporter", "activate")
  
  util.wait(beamDelay)

  -- Give status effect that teleports the player to the spawn.
  world.sendEntityMessage(sourceId, "applyStatusEffect", teleportStatusEffect)

  local pos = object.position()
  
  -- Draw beams that connect to the player.
  local chains = {}

  for _, offset in ipairs(chainsConfig.startOffsets) do
    local chain = copy(chainsConfig.properties)
    
    chain.startPosition = vec2.add(pos, offset)
    chain.endPosition = world.entityPosition(sourceId)
    
    table.insert(chains, chain)
  end

  object.setAnimationParameter("chains", chains)
  
  util.wait(chainsConfig.activeDuration)
  
  -- Derender chains
  object.setAnimationParameter("chains", {})

  util.wait(deactivationDelay)

  -- Turn off lights
  animator.setAnimationState("teleporter", "deactivate")

  teleporterState:set(noop)

  object.setInteractive(true)
end

-- Does nothing on each update
function noop()
  while true do
    coroutine.yield()
  end
end

-- Sets the teleporter state to begin the teleportation.
function onInteraction(args)
  teleporterState:set(teleport, args.sourceId)
end