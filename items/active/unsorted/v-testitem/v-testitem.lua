require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
end

function update(dt, fireMode)
  local queried = world.entityQuery(mcontroller.position(), 50, {
    includedTypes = {"monster"}
  })

  if fireMode == "primary" then
    for _, entityId in ipairs(queried) do
      world.sendEntityMessage(entityId, "notify", {
        type = "flyToPosition",
        targetPosition = activeItem.ownerAimPosition()
      })
    end
  end
end