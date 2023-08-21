--[[
  Simple script that makes the current object transform into a new object. It will do nothing if the new object is
  undefined to allow for placeholder objects.
]]

function init()
  local newObject = config.getParameter("newObject")
  
  if not newObject then
    return false
  end
  
  local isTileProtected = world.isTileProtected(object.position())
  local dungeonId = world.dungeonId(object.position())
  
  object.smash(true)

  -- Temporarily disable tile protection so that it can place the new object.
  if isTileProtected then
    world.setTileProtection(dungeonId, false)
  end
  
  world.placeObject(newObject, object.position(), object.direction())
  
  -- Turn tile protection back on.
  if isTileProtected then
    world.setTileProtection(dungeonId, true)
  end
end