require "/scripts/vec2.lua"
require "/scripts/v-world.lua"

function init()
  message.setHandler("v-spireportalchestplacer-trigger", placeChest)
end

function placeChest()
  local smashOnPlacement = config.getParameter("smashOnPlacement")
  local objectType = config.getParameter("placementObjectType")
  local objectOffset = config.getParameter("objectOffset", {0, 0})
  local objectParameters = config.getParameter("objectParameters", {})
  local projectileType = config.getParameter("projectileType")
  local projectileOffset = config.getParameter("projectileOffset", {0, 0})

  local pos = vec2.add(object.position(), objectOffset)  --[[@as Vec2I]]
  local projectilePos = vec2.add(object.position(), projectileOffset)
  -- world.spawnProjectile(projectileType, projectilePos)
  vWorld.forcePlaceObject(objectType, pos, 1, objectParameters)
  if smashOnPlacement then
    object.smash()
  end
end