require "/scripts/vec2.lua"

local targetId

function init()
  targetId = config.getParameter("target")

  if not targetId then
    script.setUpdateDelta(0)
  end
end

function update()
  local direction = entity.distanceToEntity(targetId)

  mcontroller.setRotation(vec2.angle(direction))
end