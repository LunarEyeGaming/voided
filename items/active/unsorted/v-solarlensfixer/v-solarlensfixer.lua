require "/scripts/vec2.lua"

local fixRange
local broadcastRange

function init()
  fixRange = config.getParameter("fixRange")
  broadcastRange = config.getParameter("broadcastRange")
end

function update(dt, fireMode)
  local aimPos = activeItem.ownerAimPosition()

  world.debugPoint(aimPos, canFixLens(aimPos) and "green" or "red")

  if fireMode == "primary" and prevFireMode ~= fireMode and canFixLens(aimPos) then
    fixLens(aimPos)
  end

  prevFireMode = fireMode
end

function canFixLens(aimPos)
  return world.magnitude(aimPos, mcontroller.position()) <= fixRange
end

function fixLens(aimPos)
  local queried = world.entityQuery(aimPos, broadcastRange, {includedTypes = {"object"}, order = "nearest"})

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "v-solarLens-fix")
  end
end

function uninit()

end

