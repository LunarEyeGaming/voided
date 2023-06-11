require "/scripts/rect.lua"

local oldDestroy = destroy or function() end

function destroy()
  oldDestroy()
  for _, entityId in ipairs(world.players()) do
    world.sendEntityMessage(entityId, "v-updateRegion", rect.translate(config.getParameter("matUpdateRegion"),
        mcontroller.position()))
  end
end