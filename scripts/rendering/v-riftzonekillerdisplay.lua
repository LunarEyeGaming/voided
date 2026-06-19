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
      local predictedPos = vEntity.predictPosition(dt)

      local queried = world.entityQuery(entity.position(), queryRange, {
        includedTypes = {"object"}
      })

      for _, entityId in ipairs(queried) do
        if world.getObjectParameter(entityId, "v-isRiftZoneKiller") then
          local entityPos = world.entityPosition(entityId)
          local entityPosRelative = world.distance(entityPos, predictedPos)
          local displaySize = world.getObjectParameter(entityId, "killRange")
          local displayPoly = {{-displaySize, -displaySize}, {displaySize, -displaySize}, {displaySize, displaySize}, {-displaySize, displaySize}}
          localAnimator.addDrawable({
            poly = displayPoly,
            position = entityPosRelative,
            color = displayColor
          }, "ForegroundOverlay+10")
        end
      end
    end
  end
end