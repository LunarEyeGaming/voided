require "/scripts/status.lua"
require "/scripts/vec2.lua"

local target

function init()
  initialDuration = effect.duration()

  animator.setAnimationRate(0)
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end

  message.setHandler("v-grabbed-sourceEntity", function(_, _, sourceId)
    target = sourceId
  end)

  message.setHandler("v-grabbed-expire", effect.expire)
end

function update(dt)
  local currentDuration = effect.duration()
  if currentDuration <= initialDuration and currentDuration > 0 then
    if not target or not world.entityExists(target) then
      effect.expire()
      return
    end
    effect.modifyDuration(initialDuration - currentDuration)
  end

  local pos = world.entityPosition(target)
  mcontroller.setPosition(pos)
  mcontroller.setVelocity({0, 0})
  mcontroller.controlModifiers({
      facingSuppressed = true,
      movementSuppressed = true
    })
end