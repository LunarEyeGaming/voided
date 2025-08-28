require "/scripts/util.lua"
require "/scripts/vec2.lua"

local targetUid
local cinematicTime
local teleportTime
local appearTime
local teleportCinematic
local teleportOffset
local beamInStatusEffect
local burstParticleEmitter

local searchPromise
local teleportState

function init()
  -- Initialize parameters
  targetUid = config.getParameter("targetUid")
  cinematicTime = config.getParameter("cinematicTime")
  teleportTime = config.getParameter("teleportTime")
  appearTime = config.getParameter("appearTime")
  teleportCinematic = config.getParameter("teleportCinematic")
  teleportOffset = config.getParameter("teleportOffset")
  burstParticleEmitter = config.getParameter("burstParticleEmitter")

  beamInStatusEffect = config.getParameter("beamInStatusEffect")

  -- Prepare async
  searchPromise = world.findUniqueEntity(targetUid)
  teleportState = FSM:new()
  teleportState:set(teleport)

  -- Begin animation
  animator.setAnimationState("teleport", "beamOut")
  if burstParticleEmitter then
    animator.burstParticleEmitter(burstParticleEmitter)
  end
  mcontroller.setVelocity({0, 0})
end

function update(dt)
  teleportState:update()
  effect.setParentDirectives(string.format("?multiply=%s", animator.animationStateProperty("teleport", "multiply") or "ffffff00"))

  -- Freeze player
  mcontroller.setVelocity({0, 0})
  mcontroller.controlModifiers({
      facingSuppressed = true,
      movementSuppressed = true
    })
end

function teleport()
  while not searchPromise:finished() do
    coroutine.yield()
  end

  if not searchPromise:succeeded() then
    sb.logWarn("In-world teleport not successful: no such entity with unique ID '%s'", targetUid)
    teleportState:set(noop)
    coroutine.yield()
  end

  targetPosition = searchPromise:result()

  util.wait(cinematicTime)

  world.sendEntityMessage(entity.id(), "playCinematic", teleportCinematic)

  util.wait(teleportTime)

  mcontroller.setPosition(vec2.add(targetPosition, teleportOffset))
  world.sendEntityMessage(targetUid, "preactivate")

  util.wait(appearTime)

  world.sendEntityMessage(targetUid, "activate", entity.id())
  status.addEphemeralEffect(beamInStatusEffect)
  effect.expire()

  teleportState:set(noop)
end

function noop()
  while true do
    coroutine.yield()
  end
end

function trigger()

end