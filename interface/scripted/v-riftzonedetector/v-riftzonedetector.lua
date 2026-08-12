require "/scripts/rect.lua"

local detectionRegion
local canvas  ---@type CanvasWidget

function init()
  detectionRegion = {-300, -300, 300, 300}
  canvas = widget.bindCanvas("screenCanvas")
end

function update(dt)
  canvas:clear()

  local riftZones = world.getProperty("v-riftZones") or jarray()

  local ownPos = world.entityPosition(player.id())
  for _, riftZone in ipairs(riftZones) do
    local pos = vec2.mul(world.distance(riftZone.position, ownPos), 1 / 6)
    if rect.contains(detectionRegion, pos) then
      canvas:drawImageDrawable("/interface/scripted/v-riftzonedetector/point.png", vec2.add(pos, {50, 50}), 1)
    end
  end

  for _, entityId in ipairs(world.entityQuery(ownPos, 300, {includedTypes = {"monster"}})) do
    if world.monsterType(entityId) == "v-riftzone" then
      local pos = vec2.mul(world.distance(world.entityPosition(entityId), ownPos), 1 / 6)
      canvas:drawImageDrawable("/interface/scripted/v-riftzonedetector/point.png", vec2.add(pos, {50, 50}), 1)
    end
  end
end