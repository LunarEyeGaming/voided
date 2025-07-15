require "/scripts/vec2.lua"

local oldDestroy = destroy or function() end

function destroy()
  oldDestroy()

  world.spawnTreasure(mcontroller.position(), config.getParameter("treasurePool"), world.threatLevel())
end