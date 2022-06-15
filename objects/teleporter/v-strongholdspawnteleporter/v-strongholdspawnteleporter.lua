require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.teleportStatusEffect = "v-ancientstrongholdteleport"
  self.chains = config.getParameter("chains")
  self.beamDelay = config.getParameter("beamDelay", 0.5)
  self.deactivationDelay = config.getParameter("deactivationDelay", 0.5)
  object.setInteractive(true)
  
  self.state = FSM:new()
  self.state:set(noop)
end

function update()
  self.state:update()
end

function teleport(sourceId)
  animator.setAnimationState("teleporter", "activate")
  
  util.wait(self.beamDelay)

  world.sendEntityMessage(sourceId, "applyStatusEffect", self.teleportStatusEffect)
  local pos = object.position()
  local chains = {}
  for _, offset in ipairs(self.chains.startOffsets) do
    local chain = copy(self.chains.properties)
    
    chain.startPosition = vec2.add(pos, offset)
    chain.endPosition = world.entityPosition(sourceId)
    
    table.insert(chains, chain)
  end
  object.setAnimationParameter("chains", chains)
  
  util.wait(self.chains.activeDuration)
  
  object.setAnimationParameter("chains", {})
  util.wait(self.deactivationDelay)
  animator.setAnimationState("teleporter", "deactivate")

  self.state:set(noop)
end

function noop()
  while true do
    coroutine.yield()
  end
end

function onInteraction(args)
  self.state:set(teleport, args.sourceId)
end