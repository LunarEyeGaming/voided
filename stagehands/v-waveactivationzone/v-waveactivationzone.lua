require "/scripts/vec2.lua"
require "/scripts/stagehandutil.lua"

require "/scripts/v-entity.lua"

function init()
  message.setHandler("v-getActivationZone", function()
    return vEntity.getRegionPoints(config.getParameter("broadcastArea", {-8, -8, 8, 8}))
  end)

  message.setHandler("v-die", stagehand.die)
end