require "/scripts/v-entity.lua"
require "/scripts/poly.lua"

local displayColor
local queryRange

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  displayColor = {79, 20, 92, 63}
  queryRange = 128
end

function update(dt)
  localAnimator.clearDrawables()

  oldUpdate(dt)

  local heldItem = player.primaryHandItem()
  if heldItem then
    local itemConfig = root.itemConfig(heldItem.name)
    if itemConfig.config["v-isRiftZoneKiller"] or itemConfig.parameters["v-isRiftZoneKiller"] then
      local queried = world.entityQuery(entity.position(), queryRange, {
        includedTypes = {"object"}
      })

      for _, entityId in ipairs(queried) do
        if world.getObjectParameter(entityId, "v-isRiftZoneKiller") then
          local entityPos = world.entityPosition(entityId)
          local displaySize = world.getObjectParameter(entityId, "killRange")
          drawBox(entityPos, displaySize, dt)
        end
      end

      if world.entityAimPosition then
        local aimPos = vec2.floor(world.entityAimPosition(entity.id()))
        local displaySize = itemConfig.parameters.killRange or itemConfig.config.killRange

        drawBox(aimPos, displaySize, dt)
      end
    end
  end
end

function drawBox(center, size, dt)
  local predictedPos = vEntity.predictPosition(dt)

  local centerRelative = world.distance(center, predictedPos)
  local displayPoly = {{-size, -size}, {size, -size}, {size, size}, {-size, size}}
  localAnimator.addDrawable({
    poly = displayPoly,
    position = centerRelative,
    color = displayColor
  }, "ForegroundOverlay+10")
end