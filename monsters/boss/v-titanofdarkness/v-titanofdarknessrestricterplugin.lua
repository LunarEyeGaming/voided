--[[
  Script that makes it so that only one Titan may exist in a world at a time and that it can spawn only inside of
  regions with dungeon ID 65535. This works by running a check for all dungeon IDs within the entity's bounding box
  immediately after spawning. It immediately despawns if any dungeon ID is not 65535. If it does not have a uniqueId, it
  then sets its uniqueId to "v-titanofdarkness" if an entity with that uniqueId does not exist, otherwise killing
  itself. This is to be used by the Titan's monster type (particularly a base-level script). If any scripts loaded by
  the Titan override the init, update, or die hooks, this script should be loaded after it.
]]

require "/scripts/rect.lua"

local oldInit = init or function() end
local oldUninit = uninit or function() end

local REQUIRED_DUNGEON_ID = 65535

function init()
  oldInit()

  -- If the Titan does not have a uniqueId assigned...
  if not entity.uniqueId() then
    -- Find the entity with uniqueId "v-titanofdarkness"
    local titanId = world.loadUniqueEntity("v-titanofdarkness")

    -- If there is one...
    if titanId ~= 0 then
      -- Disappear.
      monster.setUniqueId()
      status.setResourcePercentage("health", 0.0)
      monster.setDropPool(nil)
      self.shouldDie = true
      mcontroller.setPosition({0, 0})
    else
      monster.setUniqueId("v-titanofdarkness")
    end
  end

  -- If the Titan is not in a monster spawn zone...
  if not isInMonsterSpawnZone() then
    -- Disappear.
    monster.setUniqueId()
    status.setResourcePercentage("health", 0.0)
    monster.setDropPool(nil)
    self.shouldDie = true
    mcontroller.setPosition({0, 0})
  end
end

function uninit()
  oldUninit()

  sb.logInfo("uninit called")

  -- If this is the active Titan and it has died, unset it.
  if world.getProperty("v-activeTitanOfDarkness") == entity.id() then
    sb.logInfo("attempting to unset v-activeTitanOfDarkness")
    world.setProperty("v-activeTitanOfDarkness", nil)
  end
end

---Returns `true` if all spaces that the player's bounding box occupies have a dungeon ID of REQUIRED_DUNGEON_ID,
---`false` otherwise.
---@return boolean
function isInMonsterSpawnZone()
  local boundBox = rect.translate(mcontroller.boundBox(), mcontroller.position())

  for x = boundBox[1], boundBox[3] do
    for y = boundBox[2], boundBox[4] do
      if world.dungeonId({x, y}) ~= REQUIRED_DUNGEON_ID then
        return false
      end
    end
  end

  return true
end