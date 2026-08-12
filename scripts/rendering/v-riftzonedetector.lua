require "/scripts/rect.lua"

local detectionRegion
local canvas  ---@type CanvasWidget

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()
  detectionRegion = {-300, -300, 300, 300}
end

function update(dt)
  localAnimator.clearDrawables()

  oldUpdate(dt)

  local riftZones = world.getProperty("v-riftZones") or jarray()

  local ownPos = world.entityPosition(player.id())
  for _, riftZone in ipairs(riftZones) do
    local pos = world.distance(riftZone.position, ownPos)
    if rect.contains(detectionRegion, pos) then
      localAnimator.addDrawable({image = "/interface/scripted/v-riftzonedetector/point.png", position = vec2.mul(pos, 1 / 48), fullbright = true}, "ForegroundOverlay+256")
    end
  end

  for _, entityId in ipairs(world.entityQuery(ownPos, 300, {includedTypes = {"monster"}})) do
    if world.monsterType(entityId) == "v-riftzone" then
      local pos = world.distance(world.entityPosition(entityId), ownPos)
      localAnimator.addDrawable({image = "/interface/scripted/v-riftzonedetector/point.png", position = vec2.mul(pos, 1 / 48), fullbright = true}, "ForegroundOverlay+256")
    end
  end
end