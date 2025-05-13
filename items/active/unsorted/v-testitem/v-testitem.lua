require "/scripts/util.lua"
require "/scripts/vec2.lua"

local prevFireMode

function init()
end

function update(dt, fireMode)
  if fireMode ~= prevFireMode then
    if fireMode == "primary" then
      addSolarFlare()
    elseif fireMode == "alt" then
      clearSolarFlares()
    end
  end
  prevFireMode = fireMode
end

function addSolarFlare()
  local solarFlares = world.getProperty("v-solarFlares") or {}

  table.insert(solarFlares, {
    x = activeItem.ownerAimPosition()[1],
    startTime = world.time(),
    duration = 10,
    potency = 0.5,
    spread = 300
  })

  world.setProperty("v-solarFlares", solarFlares)
end

function clearSolarFlares()
  world.setProperty("v-solarFlares", jarray())
end