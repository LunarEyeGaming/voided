require "/scripts/vec2.lua"
local stuckEntityId
local stuckOffset

function init()
  stuckEntityId = config.getParameter("stuckEntityId")
  stuckOffset = config.getParameter("stuckOffset")
end

function update(dt)
  local stuckEntityPos = world.entityPosition(stuckEntityId)

  -- If the entity exists...
  if stuckEntityPos then
    mcontroller.setPosition(vec2.add(stuckEntityPos, stuckOffset))
  else
    projectile.die()
  end
end