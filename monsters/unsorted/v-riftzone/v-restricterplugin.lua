--[[
  Script that makes it so that a rift zone can spawn only inside of regions with dungeon IDs 65535 or 65533. This works
  by running a check for all dungeon IDs within the entity's bounding box immediately after spawning. It immediately
  despawns if any dungeon ID is not 65535 or 65533. This is to be used by the rift zone's monster type (particularly a
  base-level script). If any scripts loaded by the rift zone override the init hook, this script should be loaded after
  it.
]]

require "/scripts/rect.lua"

local oldInit = init or function() end

local REQUIRED_DUNGEON_ID = 65535
local REQUIRED_DUNGEON_ID2 = 65533

function init()
  -- If the rift zone is not in a monster spawn zone (and spawnAnywhere is false)...
  if not config.getParameter("spawnAnywhere") and not isInMonsterSpawnZone() then
    -- Disappear.
    monster.setUniqueId()
    status.setResourcePercentage("health", 0.0)
    monster.setDropPool(nil)
    self.shouldDie = true
    script.setUpdateDelta(0)  -- Suppress calls to update

    return  -- Don't initialize
  end

  oldInit()
end

---Returns `true` if all spaces that the Titan's bounding box occupies have a dungeon ID of REQUIRED_DUNGEON_ID or
---REQUIRED_DUNGEON_ID2, `false` otherwise.
---@return boolean
function isInMonsterSpawnZone()
  local boundBox = rect.translate(mcontroller.boundBox(), mcontroller.position())

  for x = boundBox[1], boundBox[3] do
    for y = boundBox[2], boundBox[4] do
      local dungeonId = world.dungeonId({x, y})
      if dungeonId ~= REQUIRED_DUNGEON_ID and dungeonId ~= REQUIRED_DUNGEON_ID2 then
        return false
      end
    end
  end

  return true
end