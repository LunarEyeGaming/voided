require "/scripts/v-movement.lua"

local targetPos
local maxTargetRange
local shouldCollide

function init()
  targetPos = config.getParameter("targetPos")
  maxTargetRange = config.getParameter("maxTargetRange")
  shouldCollide = false

  message.setHandler("v-meteorwand-attract", function(_, _, pos, speed, force)
    vMovement.approachPosition(pos, speed, force)
    targetPos = pos
  end)
end

function update(dt)
  if not shouldCollide then
    if world.magnitude(mcontroller.position(), targetPos) < maxTargetRange then
      shouldCollide = true
    end
    mcontroller.applyParameters({collisionEnabled = false})
  else
    mcontroller.applyParameters({collisionEnabled = true})
  end
end