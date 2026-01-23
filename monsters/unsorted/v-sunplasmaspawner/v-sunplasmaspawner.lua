function init()
  local liquidId = config.getParameter("liquidId")
  local quantity = config.getParameter("quantity")
  local position = mcontroller.position()
  local isTileProtected = world.isTileProtected(position)
  local dungeonId = world.dungeonId(position)

  -- Temporarily disable tile protection so that it can place the object.
  if isTileProtected then
    world.setTileProtection(dungeonId, false)
  end

  world.spawnLiquid(position, liquidId, quantity)

  -- Turn tile protection back on.
  if isTileProtected then
    world.setTileProtection(dungeonId, true)
  end

  monster.setDamageBar("None")
end

function shouldDie()
  return true
end