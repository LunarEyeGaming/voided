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
  local queried = world.entityQuery(mcontroller.position(), 1, {
    includedTypes = {"monster"}
  })

  for _, entityId in ipairs(queried) do
    if world.monsterType(entityId) == world.monsterType(entity.id()) then
      -- Disappear.
      monster.setUniqueId()
      monster.setDropPool(nil)
      g_shouldDieVar = true
      script.setUpdateDelta(0)  -- Suppress calls to update

      return
    end
  end

  oldInit()
end