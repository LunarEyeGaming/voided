require "/scripts/vec2.lua"

local displayQueryRange
local queryRange
local lowerLeftPos
local upperRightPos

function init()
  local cfg = root.assetJson("/v-riftzones.config")
  displayQueryRange = config.getParameter("killRange")
  queryRange = displayQueryRange + cfg.defaultZoneRadius
  lowerLeftPos = vec2.add(object.position(), {-queryRange, -queryRange})
  upperRightPos = vec2.add(object.position(), {queryRange, queryRange})
end

function update(dt)
  world.debugPoly({
    vec2.add(object.position(), {-queryRange, -queryRange}),
    vec2.add(object.position(), {-queryRange, queryRange}),
    vec2.add(object.position(), {queryRange, queryRange}),
    vec2.add(object.position(), {queryRange, -queryRange})
  }, "green")
  local queried = world.entityQuery(lowerLeftPos, upperRightPos, {
    includedTypes = {"monster"},
    callScript = "v_isRiftZone"
  })

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "v-riftzone-kill")
  end
end