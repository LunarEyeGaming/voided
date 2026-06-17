require "/scripts/vec2.lua"

local queryRange
local lowerLeftPos
local upperRightPos

function init()
  queryRange = 160
  lowerLeftPos = vec2.add(object.position(), {-queryRange, -queryRange})
  upperRightPos = vec2.add(object.position(), {queryRange, queryRange})
end

function update(dt)
  local queried = world.entityQuery(lowerLeftPos, upperRightPos, {
    includedTypes = {"monster"},
    callScript = "v_isRiftZone"
  })

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "v-riftzone-kill")
  end
end