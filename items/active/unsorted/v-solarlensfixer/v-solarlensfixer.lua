require "/scripts/vec2.lua"

local fixRange

function init()
  fixRange = config.getParameter("fixRange")
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
  local queried = world.entityQuery(aimPos, 1, {includedTypes = {"object"}, order = "nearest"})

  if queried[1] then
    world.sendEntityMessage(queried[1], "v-solarLens-fix")
  end
end

function uninit()

end

