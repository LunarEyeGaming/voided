require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  -- Initialize parameters
  self.targetUid = config.getParameter("targetUid")
  self.cinematicTime = config.getParameter("cinematicTime")
  self.teleportTime = config.getParameter("teleportTime")
  self.appearTime = config.getParameter("appearTime")
  self.teleportCinematic = config.getParameter("teleportCinematic")
  self.teleportOffset = config.getParameter("teleportOffset")

  self.beamInStatusEffect = config.getParameter("beamInStatusEffect")

  -- Prepare async
  self.promise = world.findUniqueEntity(self.targetUid)
  self.state = FSM:new()
  self.state:set(teleport)

  -- Begin animation
  animator.setAnimationState("teleport", "beamOut")
  mcontroller.setVelocity({0, 0})
end

function update(dt)
  self.state:update()
  effect.setParentDirectives(string.format("?multiply=%s", animator.animationStateProperty("teleport", "multiply") or "ffffff00"))
  
  -- Freeze player
  mcontroller.setVelocity({0, 0})
  mcontroller.controlModifiers({
      facingSuppressed = true,
      movementSuppressed = true
    })
end

function teleport()
  while not self.promise:finished() do
    coroutine.yield()
  end
  
  if not self.promise:succeeded() then
    sb.logWarn("In-world teleport not successful: no such entity with unique ID '%s'", self.targetUid)
    self.state:set(noop)
    coroutine.yield()
  end
  
  self.targetPosition = self.promise:result()
  
  util.wait(self.cinematicTime)
  
  world.sendEntityMessage(entity.id(), "playCinematic", self.teleportCinematic)
  
  util.wait(self.teleportTime)
  
  mcontroller.setPosition(vec2.add(self.targetPosition, self.teleportOffset))
  world.sendEntityMessage(self.targetUid, "preactivate")
  
  util.wait(self.appearTime)
  
  world.sendEntityMessage(self.targetUid, "activate", entity.id())
  status.addEphemeralEffect(self.beamInStatusEffect)
  effect.expire()
  
  self.state:set(noop)
end

function noop()
  while true do
    coroutine.yield()
  end
end

function trigger()
  
end